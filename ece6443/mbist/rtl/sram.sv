module sram #(parameter int ADDR_WIDTH = 6, DATA_WIDTH = 8)(
    input logic clk,
    input logic [ADDR_WIDTH-1:0] ramaddr,
    input logic [DATA_WIDTH-1:0] ramin, // for write operation
    // control signals
    input logic cs,
    input logic rwbar,
  
    output logic [DATA_WIDTH-1:0] ramout
);
    logic [ADDR_WIDTH-1:0] addr_reg;
    logic [DATA_WIDTH-1:0] ram[0:(1<<ADDR_WIDTH)-1]; // 64 words of RAM, each word is 8 bits
        
    always_ff @(posedge clk) begin
        if (cs) begin
            addr_reg <= ramaddr; // latch the address on the rising edge of the clock when chip select is active
            if (!rwbar) begin
                ram[ramaddr] <= ramin; // write data to RAM at the specified address
            end
        end
    end

    always_comb begin
        if(cs && rwbar) begin // read operation
            ramout = ram[addr_reg];
        end
        else begin
            ramout = '0; // write or other operations is zero.
        end 
    end
endmodule