module mbist_top #(
    parameter int ADDR_W = 6,   // address width
    parameter int DATA_W = 8    // data width
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  start,      // trigger MBIST

    // Normal-mode memory interface
    input  logic                  csin,       // chip-select (active-high)
    input  logic                  rwbarin,    // 0 = write, 1 = read
    input  logic                  opr,        // gate fail checking (per spec)
    input  logic [ADDR_W-1:0]     address,
    input  logic [DATA_W-1:0]     datain,
    output logic [DATA_W-1:0]     dataout,
    output logic                  fail         // asserted on BIST mismatch check
);

    // ---------------------------------------------------------------------
    // Internal nets
    // ---------------------------------------------------------------------
    logic        NbarT;                // 1 = test path
    logic        ld;                   // counter load
    logic [9:0]  q_cnt;                // counter output (length=10)
    logic [DATA_W-1:0] data_test;      // decoder pattern
    logic [DATA_W-1:0] ramout;
    logic        gt, eq, lt;
    logic        cout;                 // counter terminal flag
    logic        rwbar_int, cs_int;
    logic [ADDR_W-1:0] addr_int;
    logic [DATA_W-1:0] din_int;

    logic [9:0] CNT_SEED;
    assign CNT_SEED = 10'b0;

    assign rwbar_int = NbarT ? q_cnt[6] : rwbarin;
    assign cs_int = NbarT ? 1'b1 : csin;

    assign dataout = ramout;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            fail <= 1'b0;
        end else begin
            fail <= (NbarT && rwbar_int && !eq && opr);
        end
    end

    decoder u_decoder (
        .q(q_cnt[2:0]),
        .data_t(data_test)
    );

    counter #(.length(10)) u_counter(
        .clk(clk),
        .cen(NbarT), // counter enable signal
        .ld(ld), // load signal, when high, the counter will load the value of d_in to output q: q <= din
        .u_d(1'b1), // up/down signal, when high, the counter will count up, otherwise it will count down
        .d_in(CNT_SEED), // [length-1:0] input value
        .q(q_cnt),    // counter output
        .cout(cout)   // termination or done signal, when high, it indicates the counter has reached its maximum (for up counting) or minimum (for down counting) value 
    );

    controller u_controller(
        .clk(clk),
        .rst(rst),
        .start(start),
        .cout(cout),
        .NbarT(NbarT),
        .ld(ld)
    );

    comparator u_comparator(
        .data_t(data_test),
        .ramout(ramout),
        .gt(gt),
        .eq(eq),
        .lt(lt)
    );

    multiplexer #(.WIDTH(ADDR_W)) u_addr_mux (
        .NbarT(NbarT),
        .normal_in(address),
        .bist_in(q_cnt[ADDR_W-1:0]),
        .out(addr_int)
    );

    multiplexer #(.WIDTH(DATA_W)) u_data_mux (
        .NbarT(NbarT),
        .normal_in(datain),
        .bist_in(data_test),
        .out(din_int)
    );

    sram #(.ADDR_WIDTH(ADDR_W), .DATA_WIDTH(DATA_W)) u_sram (
        .clk(clk),
        .ramaddr(addr_int),
        .ramin(din_int),
        .cs(cs_int),
        .rwbar(rwbar_int),
        .ramout(ramout)
    );

endmodule
