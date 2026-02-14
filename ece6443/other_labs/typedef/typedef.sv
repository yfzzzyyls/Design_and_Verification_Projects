// typedef int unsigned uint_t;
// typedef logic signed sReg_t;

// input uint_t [3:0] in1; 

// input sReg_t [3:0] in2;
/*
comment seciont
*/

package definition_pkg;
    typedef int unsigned uint_t;
    typedef logic [31:0] word_t;
    typedef enum logic [1:0] {ADD=2'b00, SUB=2'b01, MUL=2'b10, DIV=2'b11} opcodes_t;


// $uint declaration space 

module add (
    input operator;
    parameters 
) (
    ports
);
    
endmodule