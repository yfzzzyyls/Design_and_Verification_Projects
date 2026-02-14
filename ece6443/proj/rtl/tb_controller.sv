// ============================================================================
//  Test‑bench for controller.sv (PASS / FAIL)
// ----------------------------------------------------------------------------
//  Verifies two‑state FSM behaviour:
//    • After reset  → RESET state (NbarT=0, ld=1)
//    • start=1     → enter TEST   (NbarT=1, ld=0) next clock
//    • cout=1      → return RESET (NbarT=0, ld=1) next clock
//  Bench prints exactly "PASS" or "FAIL".
// ============================================================================

module tb_controller;

    // DUT interface
    logic clk;
    logic rst;
    logic start;
    logic cout;
    wire  NbarT;
    wire  ld;

    // Instantiate DUT
    controller dut (
        .clk   (clk  ),
        .rst   (rst  ),
        .start (start),
        .cout  (cout ),
        .NbarT (NbarT),
        .ld    (ld   )
    );

    // ---------------------------------------------------------------------
    // 100‑MHz free‑running clock
    // ---------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;     // 10 ns period

    // Wait for one posedge + delta
    task automatic wait_clk;
        @(posedge clk);
        #1;
    endtask

    // Unified FAIL helper
    task automatic fail;
        $display("FAIL");
        $finish;
    endtask

    // ---------------------------------------------------------------------
    // Stimulus
    // ---------------------------------------------------------------------
    initial begin
        // ----------- 0. Apply asynchronous reset -----------
        rst   = 1;
        start = 0;
        cout  = 0;
        wait_clk;            // 1st clock with reset
        rst = 0;             // de‑assert reset

        // Check RESET state outputs
        wait_clk;
        if (NbarT !== 0 || ld !== 1) fail();

        // Stay in RESET for 3 cycles with start=0
        repeat (3) begin
            wait_clk;
            if (NbarT !== 0 || ld !== 1) fail();
        end

        // ----------- 1. Assert start to enter TEST ----------
        start = 1;
        wait_clk;            // start sampled
        start = 0;           // de‑assert
        // Next cycle should be TEST
        wait_clk;
        if (NbarT !== 1 || ld !== 0) fail();

        // Remain in TEST with cout=0 for 4 cycles
        repeat (4) begin
            wait_clk;
            if (NbarT !== 1 || ld !== 0) fail();
        end

        // ----------- 2. Assert cout to exit TEST ------------
        cout = 1;
        wait_clk;            // cout sampled
        cout = 0;            // back low
        // Next cycle should return to RESET
        wait_clk;
        if (NbarT !== 0 || ld !== 1) fail();

        // PASS if reached here
        $display("PASS");
        $finish;
    end

endmodule