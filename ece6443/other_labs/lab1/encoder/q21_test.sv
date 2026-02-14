module test();
    // DUT signal
    logic [3:0] I;
    logic [1:0] Y;

    // instantiate DUT
    pri_en dut(
        .I(I),
        .Y(Y)
    );

    // Dump waveform
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars;
    end

    // test case
    initial begin
        #10 // wait 10ns see if input and output are both in x state
        I = 4'b0000; // Y should stays at x
        #10
        I = 4'b0001;
        #10
        I = 4'b0010;
        #10
        I = 4'b0100;
        #10
        I = 4'b1000;
        #10
        I = 4'b0101; // priority case
        #10
        I = 4'b1111; // priority case
        #50
        $finish(0);
    end

endmodule
