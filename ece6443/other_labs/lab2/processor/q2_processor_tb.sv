module tb_processor;
    // Testbench signals
    logic [31:0] data_in;
    logic [31:0] i_data;
    logic        data_select;
    logic        clk;
    logic        rstN;
    logic [15:0] status_flags;
    logic [31:0] data_out;
    logic [7:0]  status;
    logic [2:0]  Q;

    // dump the waveform
    initial begin
            $fsdbDumpfile("dump.fsdb");
            $fsdbDumpvars;
    end

    // Instantiate the processor module (Unit Under Test)
    processor uut (
        .data_in(data_in),
        .i_data(i_data),
        .data_select(data_select),
        .clk(clk),
        .rstN(rstN),
        .status_flags(status_flags),
        .data_out(data_out),
        .status(status),
        .Q(Q)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        // Initial conditions
        data_in       = 32'hAAAA_AAAA;
        i_data        = 32'h5555_5555;
        data_select   = 1'b0;           // Initially select i_data (since mux selects 'a' when data_select is high)
        status_flags  = 16'h0000;       // Initial status flags (all zeros)
        rstN          = 1'b0;           // Apply reset (active-low)
        
        #10;                         // Wait 10 time units
        rstN = 1'b1;                 // Release reset
        
        #10;                         // Wait a few clock cycles
        
        data_select = 1'b0;
        #10;  // Observe data_out
        
        data_select = 1'b1;
        #10;
        
        data_in      = 32'hDEAD_BEEF;
        i_data       = 32'hCAFEBABE;
        // bit0 = int_en, bit1 = zero, bit2 = carry, bit3 = neg, bits[5:4] = parity
        status_flags = 16'b0000_1010_0000_0101;  
        #10;
        
        data_select = 1'b0;
        #10;
        data_select = 1'b1;
        #10;
        
        status_flags = 16'b0000_0001_0000_0011;
        #20;

        $finish(0);
    end
endmodule