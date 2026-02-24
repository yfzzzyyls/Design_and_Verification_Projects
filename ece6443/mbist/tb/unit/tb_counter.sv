module tb_counter();

localparam int LENGTH = 10;

logic clk,
logic cen, // counter enable signal
logic ld, // load signal, when high, the counter will load the value of d_in to output q: q <= din
logic u_d, // up/down signal, when high, the counter will count up, otherwise it will count down
logic [length-1:0] d_in, // [length-1:0] input valuelogic [length-1:0] q,    // counter output
logic cout               // termination or done signal, when high, it indicates the counter has reached its maximum (for up counting) or minimum (for down counting) value 

counter #(.LENGTH(LENGTH)) dut_counter (
    .clk(clk),
    ...
)



endmodule