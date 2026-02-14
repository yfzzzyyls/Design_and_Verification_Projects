// ============================================================================
//  Test‑bench for bist.sv (PASS / FAIL)
// ============================================================================

module tb_bist;

    // Parameters
    localparam int AW = 6;
    localparam int DW = 8;

    // DUT interface signals
    logic                  clk, rst, start;
    logic                  csin, rwbarin, opr;
    logic [AW-1:0]         address;
    logic [DW-1:0]         datain;
    wire  [DW-1:0]         dataout;
    wire                   fail;

    // Instantiate DUT
    bist dut (
        .clk     (clk),
        .rst     (rst),
        .start   (start),
        .csin    (csin),
        .rwbarin (rwbarin),
        .opr     (opr),
        .address (address),
        .datain  (datain),
        .dataout (dataout),
        .fail    (fail)
    );

    // 100‑MHz clock generation
    initial clk = 0;
    always  #5 clk = ~clk;

    // Helper tasks
    task automatic wait_clk; @(posedge clk); #1; endtask
    task automatic fail_now;  $display("FAIL"); $finish; endtask

    // ---------------------------------------------------------------------
    //  Stimulus
    // ---------------------------------------------------------------------
    initial begin
        integer guard;

        // Reset
        rst = 1; start = 0; csin = 1; rwbarin = 1; opr = 0;
        address = '0; datain = '0;
        wait_clk;
        rst = 0;

        // Normal write then read to check pass‑through path
        csin = 1;            // chip‑select HIGH in this spec
        rwbarin = 0;         // write
        address = 6'h03;
        datain  = 8'hA5;
        wait_clk;

        rwbarin = 1;         // read
        wait_clk;            // data latency
        if (dataout !== 8'hA5) fail_now();
        csin = 0;            // deselect

        // Trigger BIST
        start = 1;
        wait_clk;
        start = 0;

        // Wait until controller returns to RESET (NbarT goes low)
        guard = 0;
        while (dut.NbarT === 1 && guard < 2000) begin
            wait_clk;
            guard++;
        end
        if (guard >= 2000) fail_now(); // timeout

        // FAIL flag must remain low for golden design
        if (fail !== 0) fail_now();

        $display("PASS");
        $finish;
    end

endmodule