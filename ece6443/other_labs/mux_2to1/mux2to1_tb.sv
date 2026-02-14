module test();
	timeunit 1ns/1ps; // 1ns with pico second of 3 decimal precision
	logic [2:0] a, b;
	logic sel;
	logic [2:0] y;

    // intantiate the design file
    mux2to1 dut(.a(a), .b(b), .sel(sel), .y(y));
    
    // sequences
    initial begin
	a = 0;
	b = 1;
	sel = 0;
	#10; // after 10 unit time
	sel = 1;
	#20;
	a = 7;
	#50;
	$finish;
    end


    //graph(dump)
    initial begin
	    $fsdbDumpfile("dump.fsdb");
	    $fsdbDumpvars;
    end

endmodule





