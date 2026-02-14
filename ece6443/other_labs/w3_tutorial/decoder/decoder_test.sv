module test();
    logic [1:0] I;
    logic enable;
    log [3:0] Y;

    // initialize the module
    decoder dut(.I(I), .enable(enable), .Y(Y))
    // or simply decoder dut(.*)
    
    // display waveform
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars;
    end

    // generate I and enable and check if the output matches the expected value
    initial begin
        enable = 1'b0;
        #20;
        I = 2'b11;
        #10
        enable = 1'b1;
        #10
        I = 2'b10;
        #10
        I = 2'b01;
        #10
        I = 2'b00;
        #10
        enable = 1'b1;
        #20
        $finish(0);
    end

endmodule