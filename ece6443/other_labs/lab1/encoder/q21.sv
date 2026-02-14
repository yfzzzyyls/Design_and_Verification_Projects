module pri_en(
    input logic [3:0] I,
    output logic [1:0] Y
);
    /*
    Please don't touch the above code,
    start writing your logic from below
    */

     /* 
    ECE6443 lab1
    Fengze Yu(fy2243)

    Section 2: 4-to-2 Priority Encoder RTL Design
    1. Implement a 4-to-2 priority encoder.
    2. Write the stimulus generation code as per your preference. Ensure that the
corresponding waveforms are obtained based on the delays provided in the
TestBench.
    3. Please refer to the zoom recording to understand the operation of Encoder.
    4. Please use the q2.sv design file provided in brightspace. You are not allowed
to modify the module name, input and output variable names.
    */

    /* Priority encoder */

    always_comb begin
        if(I[3]) Y = 2'b11;
        else if(I[2]) Y = 2'b10;
        else if(I[1]) Y = 2'b01;
        else if(I[0]) Y = 2'b00;
    end 
endmodule