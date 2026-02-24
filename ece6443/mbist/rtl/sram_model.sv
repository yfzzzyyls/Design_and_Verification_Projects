module sram #(parameter ADDR_WIDTH = 6, DATA_WIDTH = 8)(

    input clk,
    input rst,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [DATA_WIDTH-1:0] data_in, // for write operation
    // control signals
    input logic cs,
    input logic rwbar,
  
    output logic [DATA_WIDTH-1:0] data_out
);
    logic [ADDR_WIDTH-1:0] addr_reg;
    
        
    always_ff @(posedge clk) begin
        
    end



endmodule