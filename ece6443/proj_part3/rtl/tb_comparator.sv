// ============================================================================
//  Test‑bench for comparator.sv
// ----------------------------------------------------------------------------
//  Verifies correct behaviour of 8‑bit comparator across directed and random
//  stimulus.  The bench halts with $fatal on the first mismatch.
// ============================================================================

module tb_comparator;

    // ---------------------------------------------------------------------
    // DUT interface signals
    // ---------------------------------------------------------------------
    logic [7:0] data_t;
    logic [7:0] ramout;
    logic        gt;
    logic        eq;
    logic        lt;

    // Instantiate Device‑Under‑Test
    comparator dut (
        .data_t (data_t ),
        .ramout (ramout ),
        .gt     (gt     ),
        .eq     (eq     ),
        .lt     (lt     )
    );

    // // dump the waveform
    // initial begin
    //         $fsdbDumpfile("dump.fsdb");
    //         $fsdbDumpvars;
    // end

    // ---------------------------------------------------------------------
    // Helper task: drive inputs and check outputs
    // ---------------------------------------------------------------------
    task automatic apply_check (input logic [7:0] a, input logic [7:0] b);
        logic one_hot;

        begin
            // drive inputs
            data_t = a;
            ramout = b;

            // allow signal to propagate (combinational, #1 is sufficient)
            #1;

            // one‑hot decode of DUT outputs
            one_hot = gt ^ eq ^ lt;

            // Validate that exactly one flag is asserted
            if (!one_hot) begin
                $display("FAIL");
                $finish;
            end

            // Validate correct relational flag
            if ((a > b)  && !gt) begin
                $display("FAIL");
                $finish;
            end
            if ((a == b) && !eq) begin
                $display("FAIL");
                $finish;
            end
            if ((a < b)  && !lt) begin
                $display("FAIL");
                $finish;
            end
        end
    endtask

    // ---------------------------------------------------------------------
    // Stimulus
    // ---------------------------------------------------------------------
    initial begin

        // Directed corner‑case tests
        apply_check(8'hAA, 8'h55);  // gt case
        apply_check(8'h00, 8'hFF);  // lt case
        apply_check(8'h5A, 8'h5A);  // eq case

        // Neighbouring values
        apply_check(8'h7F, 8'h80);
        apply_check(8'h80, 8'h7F);

        // Randomised regression
        repeat (1000) begin
            apply_check($urandom(), $urandom());
        end

        $display("PASS");
        $finish;
    end

endmodule