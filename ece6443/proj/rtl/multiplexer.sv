// ============================================================================
//  Parameterised 2‑to‑1 Multiplexer for MBIST design
// ----------------------------------------------------------------------------
//  Selects between the system (normal) signal path and the BIST signal path
//  under control of `NbarT`.
//
//    • WIDTH parameter allows reuse for 6‑bit address and 8‑bit data buses.
//    • When NbarT = 0 → normal_in is passed through.
//    • When NbarT = 1 → bist_in   is passed through.
//
//  Typical instantiation examples:
//      multiplexer #(.WIDTH(6)) addr_mux ( ... );   // address bus
//      multiplexer #(.WIDTH(8)) data_mux ( ... );   // data bus
// ============================================================================

module multiplexer #(
    parameter int WIDTH = 8          // bus width; override per instance
)(
    input  logic [WIDTH-1:0] normal_in,  // signal from functional logic
    input  logic [WIDTH-1:0] bist_in,    // signal from MBIST block
    input  logic             NbarT,      // 0 = normal mode, 1 = test mode
    output logic [WIDTH-1:0] out         // selected output
);

    // ---------------------------------------------------------------------
    // Combinational selection
    // ---------------------------------------------------------------------
    assign out = NbarT ? bist_in : normal_in;

endmodule
