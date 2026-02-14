//4 bit adder module 
module adder_4(
        input logic [3:0] x, y,
        input logic cin,
        output logic cout,
        output logic [3:0] sum
);
	// your code goes here

        // Perform addtion with carry
        assign {cout, sum} = x + y + cin;


//         assign cout = (x + y + cin)[1];
//         assign sum  = (x + y + cin)[0];

endmodule


//16 bit adder using the four 4-bit adder
module Adder(
        input logic [15:0] X,Y,
        input logic cin,
        output logic cout,
        output logic [15:0] S
);
        // your logic code goes here
	// Initialize your sub module here

        logic c1, c2, c3;

        // Instantiate sub-module 4-bit adders
        adder_4 adder4_1 (
                .x(X[3:0]),       //  Lower 4 bits of X
                .y(Y[3:0]),       
                .cin(cin),        
                .sum(S[3:0]),     
                .cout(c1)         
        );

        adder_4 adder4_2 (
                .x(X[7:4]),       //  Next 4 bits of X
                .y(Y[7:4]),       
                .cin(c1),         
                .sum(S[7:4]),     
                .cout(c2)         
        );

        adder_4 adder4_3 (
                .x(X[11:8]),      //  Next 4 bits of X
                .y(Y[11:8]),      
                .cin(c2),         
                .sum(S[11:8]),    
                .cout(c3)        
        );

        adder_4 adder4_4 (
                .x(X[15:12]),     
                .y(Y[15:12]),     
                .cin(c3),         
                .sum(S[15:12]),   
                .cout(cout)       
        );
endmodule

