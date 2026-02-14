// ============================================================================
//  Test‑bench for counter.sv   (CEN has highest priority, internal 11‑bit reg)
// ----------------------------------------------------------------------------
//  Verifies:
//    1. Synchronous load when CEN=1
//    2. Counter holds & ignores LD when CEN=0
//    3. Up‑count overflow  (cout goes 0→1 at 0x3FF→0x000 wrap)
//    4. cout stays HIGH throughout the upper half (0x400 – 0x7FF)
//    5. Down‑count underflow (cout goes 1→0 at 0x400→0x3FF wrap)
// ----------------------------------------------------------------------------

module tb_counter;
    // ---------------------------------------------------------------------
    //  DUT parameters
    // ---------------------------------------------------------------------
    localparam int LEN = 10;
    localparam int MAX = (1 << LEN) - 1;           // 0x3FF
    localparam int HALF = (1 << LEN);              // 0x400

    // ---------------------------------------------------------------------
    //  Signals
    // ---------------------------------------------------------------------
    logic [LEN-1:0] d_in;
    logic           clk;
    logic           ld;
    logic           u_d;
    logic           cen;
    logic [LEN-1:0] q;
    logic           cout;

    // Instantiate DUT
    counter #(.length(LEN)) dut (
        .d_in (d_in),
        .clk  (clk ),
        .ld   (ld  ),
        .u_d  (u_d ),
        .cen  (cen ),
        .q    (q   ),
        .cout (cout)
    );

    // ---------------------------------------------------------------------
    // 100‑MHz clock (10 ns period)
    // ---------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    task automatic fail;
        $display("FAIL");
        $finish;
    endtask

    // Handy macro
    task automatic wait_clk; @(posedge clk); #1; endtask

    // ---------------------------------------------------------------------
    //  Main stimulus
    // ---------------------------------------------------------------------
    initial begin : main
        integer i;
        integer guard;
        guard = 0;
        // ------------------------------------------------------------
        // 1. Synchronous load with CEN = 1
        // ------------------------------------------------------------
        cen = 1;
        ld  = 1;
        u_d = 1;             // count UP later
        d_in = 10'h155;
        wait_clk;            // load happens here
        ld = 0;
        if (q !== 10'h155 || cout !== 0)
            fail();

        // ------------------------------------------------------------
        // 2. Hold with CEN=0 and ignore LD
        // ------------------------------------------------------------
        cen = 0;
        repeat (3) wait_clk; // should stay constant
        if (q !== 10'h155 || cout !== 0)
            fail();

        // Pulse LD while CEN=0 – must be ignored
        ld = 1;
        wait_clk;
        ld = 0;
        if (q !== 10'h155 || cout !== 0)
            fail();

        // Re‑enable counting
        cen = 1;

        // ------------------------------------------------------------
        // 3. Count UP to first overflow (cout 0→1)
        // ------------------------------------------------------------
 
        while (cout === 0 && guard < HALF + 10) begin
            wait_clk;
            guard++;
        end
        if (cout === 0)
            fail();

        // We just crossed the boundary: internal went 0x3FF→0x400
        if (q !== 0           || cout !== 1)
            fail();

        // ------------------------------------------------------------
        // 4. Verify cout stays HIGH for entire upper half
        // ------------------------------------------------------------
        for (i = 1; i < HALF; i++) begin
            wait_clk;
            if (cout !== 1)
                fail();
        end
        // At this point q should be 0x3FF with cout still high
        if (q !== MAX || cout !== 1)
            fail();

        // ------------------------------------------------------------
        // 5. Switch to DOWN; cout should clear at next wrap
        // ------------------------------------------------------------
        u_d = 0;     // count DOWN
        wait_clk;    // Down from 0x3FF→0x3FE but cout still 1
        if (cout !== 1)
            fail();

        // Continue counting down until cout clears
        guard = 0;
        while (cout === 1 && guard < HALF + 10) begin
            wait_clk;
            guard++;
        end
        if (cout === 1)
            fail();

        // Now we crossed 0x400→0x3FF boundary
        if (q !== MAX || cout !== 0)
            fail();

        $display("PASS");
        $finish;
    end

endmodule