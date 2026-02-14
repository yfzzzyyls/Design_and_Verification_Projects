
// ============================================================================
//  Test‑bench : tb_sram.sv
//  Verifies behaviour of the 64×8 single‑port SRAM model.
//  Prints only “PASS” or “FAIL”.
// ============================================================================

module tb_sram;

    // Parameters match DUT defaults
    localparam int DW = 8;
    localparam int AW = 6;
    localparam int DEPTH = 1 << AW;

    // DUT signals
    logic                  clk;
    logic                  cs;
    logic                  rwbar;
    logic [AW-1:0]         addr;
    logic [DW-1:0]         din;
    wire  [DW-1:0]         dout;

    // Instantiate SRAM
    sram #(.DATA_W(DW), .ADDR_W(AW)) dut (
        .clk     (clk  ),
        .cs      (cs   ),
        .rwbar   (rwbar),
        .ramaddr (addr ),
        .ramin   (din  ),
        .ramout  (dout )
    );

    // ---------------------------------------------------------------------
    // Clock generator : 100 MHz (10 ns period)
    // ---------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // Wait for one positive edge + delta
    task automatic wait_clk; @(posedge clk); #1; endtask

    // Unified fail helper
    task automatic fail;
        $display("FAIL");
        $finish;
    endtask

    // ---------------------------------------------------------------------
    // Stimulus and checks
    // ---------------------------------------------------------------------
    initial begin
        integer i;

        // ---------- Initialise ----------
        cs    = 0;
        rwbar = 1;   // read
        addr  = '0;
        din   = '0;
        wait_clk;

        // ---------- Write phase ----------
        for (i = 0; i < DEPTH; i++) begin
            cs    = 1;
            rwbar = 0;               // write
            addr  = i[AW-1:0];
            din   = i ^ 8'hA5;       // unique data pattern
            wait_clk;
        end

        // ---------- Read/verify phase ----------
        rwbar = 1;                   // read
        for (i = 0; i < DEPTH; i++) begin
            addr = i[AW-1:0];        // present address
            wait_clk;                // data available next cycle
            if (dout !== (i ^ 8'hA5)) fail();
        end

        // ---------- Chip‑select low should zero output ----------
        cs = 0;
        wait_clk;
        if (dout !== 0) fail();

        // ---------- All checks passed ----------
        $display("PASS");
        $finish;
    end

endmodule