module test();

    // define signals
    logic [3: 0] D0;
    logic [3: 0] D1;
    logic en;
    logic sel;
    logic [3: 0] Y;

    // instatiate DUT
    mux dut (   
        .D0(D0),
        .D1(D1),
        .en(en),
        .sel(sel),
        .Y(Y)
    );

    // Dump waveform
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars;
    end

    // assign test case
    initial begin
        D0 = 4'b0001;
        D1 = 4'b0010;

        // pull up en & sel in different time
        #20
        en = 0;
        #10
        en = 1;
        #10
        sel = 0;
        #10 
        sel = 1;
        #10
        sel = 0;
        #50
        $finish(0);
    end
endmodule
