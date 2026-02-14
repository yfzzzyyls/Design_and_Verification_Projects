// ============================================================================
//  Universal Up/Down Counter for MBIST project
// ----------------------------------------------------------------------------

module counter #(
    parameter int length = 10
) (
    input  logic [length-1:0] d_in,
    input  logic              clk,
    input  logic              ld,
    input  logic              u_d,
    input  logic              cen,
    output logic [length-1:0] q,
    output logic              cout
);
    // ---------------------------------------------------------------------
    // Internal cnt register, d_in will be passed to cnt_reg
    // ---------------------------------------------------------------------
    logic [length:0] cnt_reg;   // cnt[length] is overflow flag

    always_ff @(posedge clk) begin
        // start the process only when cen is high
        if (cen) begin
            // load d_in to cnt_reg
            if (ld) begin
                cnt_reg <= {1'b0, d_in};
            end
            else begin
                // Count up or down
                if (u_d) cnt_reg <= cnt_reg + 1'b1;
                else cnt_reg <= cnt_reg - 1'b1;
            end
        end
    end

    assign q    = cnt_reg[length-1:0];   // lower length(default to 10) bits
    assign cout = cnt_reg[length];       // MSB for overflow/underflow

endmodule
