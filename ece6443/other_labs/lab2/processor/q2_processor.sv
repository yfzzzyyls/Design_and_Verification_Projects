//Top level modules (make use of submodules from bottom)
module processor
( input logic [31:0] data_in,
  input logic [31:0] i_data,
  input logic data_select,
  input logic clk,
  input logic rstN,
  input logic [15:0] status_flags,
  output logic [31:0] data_out,
  output logic [7:0] status,
  output logic [2:0] Q
);

  //your design code goes here

  // Internal signals for status flags (from status_flags)
  logic int_en_sig;
  logic zero_sig;
  logic carry_sig;
  logic neg_sig;
  logic [1:0] parity_sig;
  
  assign int_en_sig  = status_flags[0];
  assign zero_sig    = status_flags[1];
  assign carry_sig   = status_flags[2];
  assign neg_sig     = status_flags[3];
  assign parity_sig  = status_flags[5:4];
  // (Bits status_flags[15:6] are not used in this implementation)

  // Instantiate the 32-bit multiplexer
  mux32 u_mux (
      .a   (data_in),
      .b   (i_data),
      .sel (data_select),
      .y   (data_out)
  );

  // Instantiate the status register
  status_reg u_status_reg (
      .clk    (clk),
      .rstN   (rstN),
      .int_en (int_en_sig),
      .zero   (zero_sig),
      .carry  (carry_sig),
      .neg    (neg_sig),
      .parity (parity_sig),
      .status1(status)
  );

  // Instantiate the priority encoder
  Pri_En u_pri_enc (
      .D (status_flags[15:8]),  // connect the 8-bit status output to the encoder input
      .Q (Q)
  );
endmodule

//multiplexer submodule
module mux32
( input logic [31:0] a,
  input logic [31:0] b,
  input logic sel,
  output logic [31:0] y
);
  always_comb begin
      if (sel == 1) begin
          y = a;
      end
      else if (sel == 0) begin
          y = b;
      end
      else begin
        y = 32'b0;
      end
  end
endmodule


//status register submodule
module status_reg
( input logic clk,
  input logic rstN,
  input logic int_en,
  input logic zero,
  input logic carry,
  input logic neg,
  input logic [1:0] parity,
  output logic [7:0] status1
);
  always_ff @(posedge clk or negedge rstN) begin
      if (!rstN) begin
          // on reset (rstN=0): clear all bits to 0
          status1 <= 8'b0000_0000;
      end else begin
          // update status bits on positive clk edge @(posedge clk)
          status1[7]   <= int_en;
          status1[6]   <= 1'b1;      
          status1[5]   <= 1'b1;      
          status1[4]   <= zero;
          status1[3]   <= carry;
          status1[2]   <= neg;
          status1[1:0] <= parity;
      end
  end
endmodule

//priority Encoder submodule
module Pri_En
( input logic [7:0] D,
  output logic [2:0] Q
);
    always_latch begin
        casez (D)
            8'b1??????? : Q = 3'b111; 
            8'b01?????? : Q = 3'b110; 
            8'b001????? : Q = 3'b101; 
            8'b0001???? : Q = 3'b100; 
            8'b00001??? : Q = 3'b011; 
            8'b000001?? : Q = 3'b010; 
            8'b0000001? : Q = 3'b001; 
            8'b00000001 : Q = 3'b000; 
            default     : ;
        endcase
    end
endmodule

/*
    module processor's implementation use some ChatCPT code
    module status_reg's implementation use some ChatCPT code
*/