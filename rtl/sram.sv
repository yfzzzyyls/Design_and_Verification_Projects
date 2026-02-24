// Simple synchronous SRAM wrapper.
// For SYNTHESIS: instantiates TSMC 16nm SRAM macro
// For SIMULATION: uses behavioral register file with hex preload
module sram #(
    parameter int MEM_WORDS = 32'd512
`ifndef SYNTHESIS
  , parameter string HEX_PATH = ""
`endif
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        mem_valid,
    input  logic        mem_instr,
    output logic        mem_ready,
    input  logic [31:0] mem_addr,
    input  logic [31:0] mem_wdata,
    input  logic [ 3:0] mem_wstrb,
    output logic [31:0] mem_rdata
);

    // ---------------------------
    // RTL memory (synthesizable)
    // ---------------------------
    logic [31:0] mem [0:MEM_WORDS-1];
    logic [31:0] rdata_q;
    logic        ready_q;

`ifndef SYNTHESIS
    // synopsys translate_off
    initial begin : preload_hex
        if (HEX_PATH != "") begin
            $display("[%0t] Loading %s", $time, HEX_PATH);
            $readmemh(HEX_PATH, mem);
        end
    end
    // synopsys translate_on
`endif

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready_q <= 1'b0;
            rdata_q <= '0;
        end else begin
            ready_q <= 1'b0;
            if (mem_valid) begin
                logic [31:0] word_addr;
                logic [31:0] read_word;
                word_addr = mem_addr[31:2];

                if (word_addr < MEM_WORDS) begin
                    read_word = mem[word_addr[8:0]];

                    if (|mem_wstrb) begin
                        if (mem_wstrb[0]) read_word[7:0]   = mem_wdata[7:0];
                        if (mem_wstrb[1]) read_word[15:8]  = mem_wdata[15:8];
                        if (mem_wstrb[2]) read_word[23:16] = mem_wdata[23:16];
                        if (mem_wstrb[3]) read_word[31:24] = mem_wdata[31:24];
                        mem[word_addr[8:0]] <= read_word;
                    end

                    rdata_q <= read_word;
                    ready_q <= 1'b1;
                end else begin
                    rdata_q <= 32'h0000_0000;
                    ready_q <= 1'b1;
                end
            end
        end
    end

    assign mem_ready = ready_q;
    assign mem_rdata = rdata_q;

endmodule
