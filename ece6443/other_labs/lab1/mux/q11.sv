module mux(
    input logic [3:0] D0, D1,
    input logic en, sel,
    output logic [3:0] Y
);
    /*
    Please don't touch the above code,
    start writing your logic from below
    */
    
    /* 
    ECE6443 lab1
    Fengze Yu(fy2243)

    Implement a 2-to-1 mux, each input is 4 bits long
    1. Implement a 4-bit multiplexer 2-to-1 RTL model.
    2. Use a select input to determine the input selection for the multiplexer. If the
select is set to 0, the multiplexer should pass input D0 and if select is set to 1,
D1 should be passed.
    3. Additionally, include an “enable” input to control the multiplexer. If enable is
0 output Y should be “0” else the output will be assigned with input based on
select value.
    4. Write the generate stimuli code according to your preference, and observe the
waveforms aligning with the specified delays in the TestBench.
    5. Please use the q1.sv design file provided in brightspace. You are not allowed
to modify the module name, input and output variable names. 
    */

    always_comb begin
        if(en == 1) begin
            if(!sel) Y = D0; // assume all combinational logic
            else if(sel) Y = D1;
            else Y = 4'b0000; // when sel is x/z state.
        end
        else if(en == 0) begin
            Y = 4'b0000;
        end
    end
endmodule: mux
    