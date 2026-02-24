module controller (
    input logic clk,
    input logic rst,
    input logic start,
    input logic cout,

    output logic NbarT,
    output logic ld
);
    typedef enum logic [1:0] { RESET, TEST } state_t;
    
    state_t state, next_state;

    always_comb begin
        // # update output based on the current state
        NbarT = (state == TEST) ? 1'b1 : 1'b0; // NbarT is high in TEST state, low in RESET state
        ld = (state == RESET) ? 1'b1 : 1'b0;
    end 

    always_comb begin
        // # state transition logic
        next_state = state; // default to hold the current state
        if (state == RESET) begin
            next_state = (start == 1'b1) ? TEST : RESET; // transition to TEST state when start is high
        end
        else if (state == TEST) begin
            next_state = (cout == 1'b1) ? RESET : TEST; // transition to RESET state when cout is high
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= RESET;
        end else begin
            state <= next_state;
        end
    end

endmodule

