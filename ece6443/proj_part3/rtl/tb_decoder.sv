
// ============================================================================
//  Test‑bench for decoder.sv     ❶ PASS / FAIL style
// ----------------------------------------------------------------------------
//  Verifies the 3‑bit → 8‑bit pattern table:
//
//   q[2:0] | data_t
//   -------+----------------
//     000  | 1010_1010
//     001  | 0101_0101
//     010  | 1111_0000
//     011  | 0000_1111
//     100  | 0000_0000
//     101  | 1111_1111
//  invalid | 8'hXX  (drives unknown)
//
//  The bench prints a single word:
//      "PASS" – all checks succeeded
//      "FAIL" – first mismatch encountered
// ============================================================================

module tb_decoder;

    // ----------------------
    //  DUT I/O
    // ----------------------
    logic [2:0] q;
    wire  [7:0] data_t;

    decoder dut ( .* );

    // ----------------------
    //  Helper: fail & exit
    // ----------------------
    task automatic fail;
        $display("FAIL");
        $finish;
    endtask

    // ----------------------
    //  Stimulus
    // ----------------------
    initial begin
        // Directed table checks
        q = 3'b000; #1; if (data_t !== 8'b1010_1010) fail();
        q = 3'b001; #1; if (data_t !== 8'b0101_0101) fail();
        q = 3'b010; #1; if (data_t !== 8'b1111_0000) fail();
        q = 3'b011; #1; if (data_t !== 8'b0000_1111) fail();
        q = 3'b100; #1; if (data_t !== 8'b0000_0000) fail();
        q = 3'b101; #1; if (data_t !== 8'b1111_1111) fail();

        // Invalid selector should yield Xs
        q = 3'b110; #1;
        if (data_t !== 8'hXX) fail();

        $display("PASS");
        $finish;
    end

endmodule
