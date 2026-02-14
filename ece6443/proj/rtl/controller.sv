// ============================================================================
//  Controller for MBIST project
// ----------------------------------------------------------------------------
//  Two‑state FSM:
//      • RESET : normal memory operation
//      • TEST  : MBIST self‑test active
//
//  Transitions
//      RESET -- start==1 --> TEST
//      TEST  -- cout==1  --> RESET
//
//  Outputs (combinational from current state)
//      • NbarT = 0 in RESET, 1 in TEST
//      • ld    = 1 in RESET, 0 in TEST   (pre‑load counter)
//
//  Synchronous to clk; rst is asynchronous active‑high.
// ============================================================================

module controller (
    input  logic clk,
    input  logic rst,    // async active‑high reset
    input  logic start,  // request MBIST
    input  logic cout,   // counter overflow / test done
    output logic NbarT,  // 0 = normal path, 1 = test path
    output logic ld      // load counter during RESET
);

    // ------------------------------------------------------------
    // State encoding
    // ------------------------------------------------------------
    typedef enum logic { reset, test } state_t;
    state_t curr, next;

    // ------------------------------------------------------------
    // Next‑state combinational logic
    // ------------------------------------------------------------
    always_comb begin
        unique case (curr)
            reset   : next = (start) ? test  : reset;
            test    : next = (cout)  ? reset : test;
            default : next = reset;             // recover from unknown state
        endcase
    end

    // ------------------------------------------------------------
    // State register with asynchronous reset
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            curr <= reset;
        else
            curr <= next;
    end

    // ------------------------------------------------------------
    // Outputs
    // ------------------------------------------------------------
    assign NbarT = (curr == test);
    assign ld    = (curr == reset);

endmodule