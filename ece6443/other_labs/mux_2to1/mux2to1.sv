module mux2to1(
	input logic [2:0] a,b,
	input logic sel,
	output logic [2:0] y
);
	timeunit 1ns/1ps;
	always_comb begin
		if(sel)	y = a;
		else y = b;
	end
endmodule: mux2to1
