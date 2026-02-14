

// ============================================================================
//  Comparator: 8‑bit combinational comparator for MBIST project
// ----------------------------------------------------------------------------
//  Compares the expected data pattern (`data_t`) with the value read from
//  SRAM (`ramout`).  Exactly one of the three one‑hot outputs is asserted.
//
//    gt : 1 when data_t  > ramout
//    eq : 1 when data_t == ramout
//    lt : 1 when data_t  < ramout
//
//  Author : <Fengze Yu>
//  Date   : <April 2025>
// ============================================================================

// `timescale 1ns / 1ps

module comparator (
    input  logic [7:0] data_t,   // expected pattern from decoder
    input  logic [7:0] ramout,   // data returned by SRAM
    output logic       gt,       // data_t > ramout
    output logic       eq,       // data_t == ramout
    output logic       lt        // data_t < ramout
);

    // ---------------------------------------------------------------------
    // Combinational compare
    // ---------------------------------------------------------------------
    always_comb begin
        gt = (data_t > ramout);
        eq = (data_t == ramout);
        lt = (data_t < ramout);
    end

    // Optional formal assertion: exactly one flag is high
endmodule