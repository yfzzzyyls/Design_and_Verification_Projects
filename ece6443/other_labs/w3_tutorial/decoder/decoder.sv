// this file will implement decoder using sv.

/*

DECODER
for example:
input = 2'b00, output = 0001
input = 2'b01, output = 0010
input = 2'b10, output = 0100
input = 2'b11, output = 1000

*/


module decoder (
    //NUM_INPUT = 2;

    input logic [2-1 : 0] I,
    input logic [1:0] enable,
    output logic [2*2-1 : 0] Y
);
    always_comb begin
        if(enable==1'b00) begin
            Y = 4'b0000;
        end
        else begin
            case(in)
            2'b00: Y = 4'b0001;
            2'b01: Y = 4'b0010;
            2'b10: Y = 4'b0100;
            2'b11: Y = 4'b1000;
            endcase
        end

endmodule