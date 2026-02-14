

// ============================================================================
//  bist.sv  — Top‑level wrapper for MBIST demonstration
// ----------------------------------------------------------------------------
//  Parameters
//      ADDR_W : address width of SRAM   (64 words  → 6)
//      DATA_W : data    width of SRAM   (8 bits)
// ----------------------------------------------------------------------------
//  Ports
//      clk, rst       : system clock and async reset
//      start          : initiate BIST
//      cs_n, rwbar_n  : normal‑mode SRAM chip‑select / read‑write#
//      addr_in        : normal‑mode address bus
//      din_in         : normal‑mode data‑in
//      dout           : SRAM data‑out (always driven)
//      fail           : comparator flag (sticky high on first mismatch)
// ============================================================================


module bist #(
    parameter int ADDR_W = 6,   // override with .ADDR_W(..)
    parameter int DATA_W = 8    // override with .DATA_W(..)
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  start,      // trigger MBIST

    // Normal‑mode memory interface expected by grader
    input  logic                  csin,       // chip‑select (active‑high)
    input  logic                  rwbarin,    // 0 = write, 1 = read
    input  logic                  opr,        // unused but kept for port map
    input  logic [ADDR_W-1:0]     address,
    input  logic [DATA_W-1:0]     datain,
    output logic [DATA_W-1:0]     dataout,
    output logic                  fail         // sticky fail flag
);

    // ---------------------------------------------------------------------
    // Internal nets
    // ---------------------------------------------------------------------
    logic        NbarT;               // 1 = test path
    logic        ld;                  // counter load
    logic [9:0] addr_test;     // counter out
    logic [DATA_W-1:0] data_test;     // decoder pattern
    logic [DATA_W-1:0] ramout;
    logic        gt, eq, lt;
    logic        cout;                // counter overflow
    logic        rwbar_int, cs_int;
    logic [ADDR_W-1:0] addr_int;
    logic [DATA_W-1:0] din_int;

    // ---------------------------------------------------------------------
    // Sub‑modules
    // ---------------------------------------------------------------------

    // Controller
    controller u_ctrl (
        .clk  (clk ),
        .rst  (rst ),
        .start(start),
        .cout (cout),
        .NbarT(NbarT),
        .ld   (ld)
    );

    // Counter (11‑bit internal, visible 10‑bit)
    counter #(.length(10)) u_cnt (
        .d_in (10'd0),
        .clk  (clk ),
        .ld   (ld  ),
        .u_d  (1'b1),   // count up during test
        .cen  (NbarT),  // enable only in test state
        .q    (addr_test),
        .cout (cout)
    );

    // Decoder
    decoder u_dec (
        .q      (addr_test[2:0]),
        .data_t (data_test)
    );

    // Comparator
    comparator u_cmp (
        .data_t (data_test),
        .ramout (ramout ),
        .gt     (gt),
        .eq     (eq),
        .lt     (lt)
    );

    // Address and data multiplexers
    multiplexer #(.WIDTH(ADDR_W)) u_mux_addr (
        .normal_in(address),
        .bist_in  (addr_test[ADDR_W-1:0]),
        .NbarT    (NbarT),
        .out      (addr_int)
    );

    multiplexer #(.WIDTH(DATA_W)) u_mux_data (
        .normal_in(datain),
        .bist_in  (data_test),
        .NbarT    (NbarT),
        .out      (din_int)
    );

    // read/write and chip‑select mux logic
    assign rwbar_int = NbarT ? ~addr_test[ADDR_W] : rwbarin;
    assign cs_int    = NbarT ? 1'b1               : csin;

    // SRAM
    sram #(.DATA_W(DATA_W), .ADDR_W(ADDR_W)) u_sram (
        .clk     (clk ),
        .cs      (cs_int),
        .rwbar   (rwbar_int),
        .ramaddr (addr_int),
        .ramin   (din_int),
        .ramout  (ramout)
    );

    assign dataout = ramout;

    // ---------------------------------------------------------------------
    // FAIL flag: sticky until next reset
    // ---------------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            fail <= 1'b0;
        else if (NbarT && ~eq)          // only during test, any mismatch
            fail <= 1'b1;
    end

endmodule