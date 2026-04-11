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

    localparam int unsigned MEM_ADDR_BITS = (MEM_WORDS <= 1) ? 1 : $clog2(MEM_WORDS);

`ifdef SYNTHESIS
    // TS1N16ADFPCLLLVTA512X45M4SWSHOD is 512x45.
    localparam int unsigned MACRO_WORDS = 512;

    logic [31:0] word_addr;
    logic        addr_in_range;
    logic        req_in_range;
    logic        write_req;

    logic [ 8:0] macro_a;
    logic [44:0] macro_d;
    logic [44:0] macro_q;
    logic [44:0] macro_bweb;
    logic [31:0] macro_bweb_lo;
    logic        macro_ceb;
    logic        macro_web;

    logic        ready_q;
    logic        resp_in_range_q;

    assign word_addr     = mem_addr[31:2];
    assign addr_in_range = (word_addr < MEM_WORDS) && (word_addr < MACRO_WORDS);
    assign req_in_range  = mem_valid && addr_in_range;
    assign write_req     = req_in_range && (|mem_wstrb);

    assign macro_a = mem_addr[10:2];
    assign macro_d = {13'b0, mem_wdata};

    // Byte strobes expand to per-bit active-low write enables.
    assign macro_bweb_lo = {
        {8{~mem_wstrb[3]}},
        {8{~mem_wstrb[2]}},
        {8{~mem_wstrb[1]}},
        {8{~mem_wstrb[0]}}
    };
    assign macro_bweb = {13'h1FFF, macro_bweb_lo};

    // CEB/WEB are active-low.
    assign macro_ceb = ~req_in_range;
    assign macro_web = ~write_req;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready_q         <= 1'b0;
            resp_in_range_q <= 1'b0;
        end else begin
            ready_q         <= mem_valid;
            resp_in_range_q <= req_in_range;
        end
    end

    assign mem_ready = ready_q;
    assign mem_rdata = (ready_q && resp_in_range_q) ? macro_q[31:0] : 32'h0000_0000;

    TS1N16ADFPCLLLVTA512X45M4SWSHOD u_sram_macro (
        .A     (macro_a),
        .BWEB  (macro_bweb),
        .CEB   (macro_ceb),
        .CLK   (clk),
        .D     (macro_d),
        .DSLP  (1'b0),
        .Q     (macro_q),
        .RTSEL (2'b00),
        .SD    (1'b0),
        .SLP   (1'b0),
        .WEB   (macro_web),
        .WTSEL (2'b00)
    );
`else
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
                    read_word = mem[word_addr[MEM_ADDR_BITS-1:0]];

                    if (|mem_wstrb) begin
                        if (mem_wstrb[0]) read_word[7:0]   = mem_wdata[7:0];
                        if (mem_wstrb[1]) read_word[15:8]  = mem_wdata[15:8];
                        if (mem_wstrb[2]) read_word[23:16] = mem_wdata[23:16];
                        if (mem_wstrb[3]) read_word[31:24] = mem_wdata[31:24];
                        mem[word_addr[MEM_ADDR_BITS-1:0]] <= read_word;
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
`endif

endmodule
