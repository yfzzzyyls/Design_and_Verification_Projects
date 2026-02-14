// ============================================================================
//  Decoder for MBIST project
// ----------------------------------------------------------------------------
//  Maps a 3‑bit selector (q) to an 8‑bit test pattern (data_t) according to
//  the table on page 3 of the project hand‑out.
//
//      q      data_t
//   --------  --------
//    000      1010_1010
//    001      0101_0101
//    010      1111_0000
//    011      0000_1111
//    100      0000_0000
//    101      1111_1111
//   default   8'hXX   (unknown)
//
//  Purely combinational.
// ============================================================================

module decoder (
    input  logic [2:0] q,      // selector from counter (q[2:0])
    output logic [7:0] data_t  // decoded 8‑bit pattern
);

    always_comb begin
        unique case (q)
            3'b000 : data_t = 8'b1010_1010;
            3'b001 : data_t = 8'b0101_0101;
            3'b010 : data_t = 8'b1111_0000;
            3'b011 : data_t = 8'b0000_1111;
            3'b100 : data_t = 8'b0000_0000;
            3'b101 : data_t = 8'b1111_1111;
            default: data_t = 8'hXX;       // invalid selector => unknown
        endcase
    end

endmodule
