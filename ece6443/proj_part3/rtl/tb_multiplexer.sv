// ============================================================================
//  Test‑bench for parameterised multiplexer.sv
// ----------------------------------------------------------------------------
//  Instantiates two DUTs (WIDTH = 6 and WIDTH = 8) and verifies correct
//  behaviour with directed cases and 1,000 random vectors.
//  The bench terminates with $fatal on the first mismatch.
// ============================================================================


module tb_multiplexer;

    // // dump the waveform
    // initial begin
    //         $fsdbDumpfile("dump.fsdb");
    //         $fsdbDumpvars;
    // end

    // ---------------------------------------------------------------------
    // Instance 1 : WIDTH = 6  (address mux)
    // ---------------------------------------------------------------------
    localparam int W1 = 6;
    logic [W1-1:0] norm1;
    logic [W1-1:0] bist1;
    logic          NbarT1;
    logic [W1-1:0] out1;

    multiplexer #(.WIDTH(W1)) u_mux_addr (
        .normal_in (norm1 ),
        .bist_in   (bist1 ),
        .NbarT     (NbarT1),
        .out       (out1  )
    );

    // ---------------------------------------------------------------------
    // Instance 2 : WIDTH = 8  (data‑in mux)
    // ---------------------------------------------------------------------
    localparam int W2 = 8;
    logic [W2-1:0] norm2;
    logic [W2-1:0] bist2;
    logic          NbarT2;
    logic [W2-1:0] out2;

    multiplexer #(.WIDTH(W2)) u_mux_data (
        .normal_in (norm2 ),
        .bist_in   (bist2 ),
        .NbarT     (NbarT2),
        .out       (out2  )
    );

    // ---------------------------------------------------------------------
    // Helper tasks : one for each width (avoid parameterised task syntax)
    // ---------------------------------------------------------------------

    task automatic check_mux6
        (
            input logic [W1-1:0] normal_in,
            input logic [W1-1:0] bist_in,
            input logic          NbarT,
            input logic [W1-1:0] out
        );
        logic [W1-1:0] expected;
        begin
            expected = NbarT ? bist_in : normal_in;
            if (out !== expected) begin
                $display("FAIL");
                $finish;
            end
        end
    endtask

    task automatic check_mux8
        (
            input logic [W2-1:0] normal_in,
            input logic [W2-1:0] bist_in,
            input logic          NbarT,
            input logic [W2-1:0] out
        );
        logic [W2-1:0] expected;
        begin
            expected = NbarT ? bist_in : normal_in;
            if (out !== expected) begin
                $display("FAIL");
                $finish;
            end
        end
    endtask

    // ---------------------------------------------------------------------
    // Stimulus
    // ---------------------------------------------------------------------
    initial begin

        // Directed cases
        norm1 = 6'h00; bist1 = 6'h3F; NbarT1 = 0;
        norm2 = 8'hAA; bist2 = 8'h55; NbarT2 = 0;
        #1;
        check_mux6(norm1, bist1, NbarT1, out1);
        check_mux8(norm2, bist2, NbarT2, out2);

        NbarT1 = 1; NbarT2 = 1;
        #1;
        check_mux6(norm1, bist1, NbarT1, out1);
        check_mux8(norm2, bist2, NbarT2, out2);

        // Randomised regression
        repeat (1000) begin
            norm1 = $urandom();
            bist1 = $urandom();
            NbarT1 = $urandom() & 1;

            norm2 = $urandom();
            bist2 = $urandom();
            NbarT2 = $urandom() & 1;

            #1;
            check_mux6(norm1, bist1, NbarT1, out1);
            check_mux8(norm2, bist2, NbarT2, out2);
        end

        $display("PASS");
        $finish;
    end

endmodule
