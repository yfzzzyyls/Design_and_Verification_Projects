module test();
        // DUT signal
        logic [15:0] X, Y;
        logic cin;
        logic cout;
        logic [15:0] S;

        // instatiate the DUT
        Adder dut(
                .X(X),
                .Y(Y),
                .cin(cin),
                .cout(cout),
                .S(S)
        );

        // dump the waveform
        initial begin
                $fsdbDumpfile("dump.fsdb");
                $fsdbDumpvars;
        end

        initial begin
                // this is equal to use a for loop
                // for(int i=0, i<100; i++){
                //       ...
                //}
                #10
                // overflow condition test
                X = 16'hFFFD;
                Y = 16'h0004;
                cin = 1;
                #10
                repeat(100) begin
                        #10
                        X = $urandom();
                        Y = $urandom();
                        cin = $urandom();
                        // void(std::randomized(x))
                end
                #10
                $finish(0);
        end
endmodule