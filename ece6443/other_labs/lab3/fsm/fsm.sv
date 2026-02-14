package fsm10_pkg;
    typedef enum logic[3:0] {S0, S1, S2, S3, S4, S5, S6, S7, S8, S9} state_e;
endpackage
module fsm(
    input logic rst_n, clk, jmp, go,
    output logic y1
);
    import fsm10_pkg::*;
    state_e state, next;
    // First deal with async reset logic, then comb logic for next state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
        end
        else begin
            state <= next;
        end
    end
    always_comb begin
        next = state; // default
        unique case (state)
            S0: begin
                if (!go) next = S0;
                else if (go && !jmp) next = S1;
                else if (go && jmp) next = S3;
            end
            S1: begin
                if (jmp) next = S3;
                else next = S2;
            end
            S2: begin
                next = S3;
            end
            S3: begin
                if (jmp) next = S3;
                else next = S4;
            end
            S4: begin
                if (jmp) next = S3;
                else next = S5;
            end
            S5: begin
                if (jmp) next = S3;
                else next = S6;
            end
            S6: begin
                if (jmp) next = S3;
                else next = S7;
            end
            S7: begin
                if (jmp) next = S3;
                else next = S8;
            end
            default: next = S0;
        endcase
    end
    // Output logic: y1 is 1 only in state S3
    always_comb begin
        y1 = (state == S3);
    end
endmodule
