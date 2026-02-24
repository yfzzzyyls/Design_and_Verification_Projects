module counter #(parameter int length = 10)
(
    input logic clk,
    input logic cen, // counter enable signal
    input logic ld, // load signal, when high, the counter will load the value of d_in to output q: q <= din
    input logic u_d, // up/down signal, when high, the counter will count up, otherwise it will count down
    input logic [length-1:0] d_in, // [length-1:0] input value
    
    output logic [length-1:0] q,    // counter output
    output logic cout               // termination or done signal, when high, it indicates the counter has reached its maximum (for up counting) or minimum (for down counting) value 
);

    logic [length-1:0] cnt_reg; // internal register to hold the counter value, cnt_reg[length - 1] is used as the cout signal

    always_ff @(posedge clk) begin
       if (cen) begin
            if(ld) begin
                cnt_reg <= d_in; // load the value of d_in to cnt_reg
            end
            else if (u_d) begin
                cnt_reg <= cnt_reg + 1; // count up
            end
            else begin
                cnt_reg <= cnt_reg - 1; // count down
            end
        end
    end

    always_comb begin
        q = cnt_reg; // assign the lower bits of cnt_reg to output q
        cout = 1'b0; // default value for cout
        if(cen && !ld) begin // count phase
            if (u_d && cnt_reg == {length{1'b1}}) begin
                cout = 1'b1; // count up and reach the maximum value
            end
            else if (!u_d && cnt_reg == {length{1'b0}}) begin
                cout = 1'b1; // count down and reach the minimum value
            end
        end
    end
endmodule