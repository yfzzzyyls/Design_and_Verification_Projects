module multiplexer #(parameter int WIDTH = 8) (
    // 1 bit sel input
    input logic NbarT,

    // 2 input data
    input logic [WIDTH-1:0] normal_in,
    input logic [WIDTH-1:0] bist_in,

    // output
    output logic [WIDTH-1:0] out
);

    assign out = (NbarT == 1'b0) ? normal_in : bist_in;

endmodule