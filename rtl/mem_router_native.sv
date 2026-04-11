module mem_router_native #(
    parameter logic [31:0] SRAM_BASE_ADDR   = 32'h0000_0000,
    parameter int unsigned SRAM_BYTES       = 32'd2048,
    parameter logic [31:0] PERIPH_BASE_ADDR = 32'h1000_0000,
    parameter int unsigned PERIPH_BYTES     = 32'd8192
) (
    input  logic        m_valid,
    input  logic        m_instr,
    output logic        m_ready,
    input  logic [31:0] m_addr,
    input  logic [31:0] m_wdata,
    input  logic [ 3:0] m_wstrb,
    output logic [31:0] m_rdata,

    output logic        sram_valid,
    output logic        sram_instr,
    input  logic        sram_ready,
    output logic [31:0] sram_addr,
    output logic [31:0] sram_wdata,
    output logic [ 3:0] sram_wstrb,
    input  logic [31:0] sram_rdata,

    output logic        periph_valid,
    output logic        periph_instr,
    input  logic        periph_ready,
    output logic [31:0] periph_addr,
    output logic [31:0] periph_wdata,
    output logic [ 3:0] periph_wstrb,
    input  logic [31:0] periph_rdata
);
    logic hit_sram;
    logic hit_periph;
    logic hit_none;

    always_comb begin
        hit_sram   = (m_addr >= SRAM_BASE_ADDR) &&
                     (m_addr < (SRAM_BASE_ADDR + SRAM_BYTES));
        hit_periph = (m_addr >= PERIPH_BASE_ADDR) &&
                     (m_addr < (PERIPH_BASE_ADDR + PERIPH_BYTES));
        hit_none   = !(hit_sram || hit_periph);

        sram_valid = m_valid && hit_sram;
        sram_instr = m_instr;
        sram_addr  = m_addr;
        sram_wdata = m_wdata;
        sram_wstrb = m_wstrb;

        periph_valid = m_valid && hit_periph;
        periph_instr = m_instr;
        periph_addr  = m_addr;
        periph_wdata = m_wdata;
        periph_wstrb = m_wstrb;

        if (hit_sram) begin
            m_ready = sram_ready;
            m_rdata = sram_rdata;
        end else if (hit_periph) begin
            m_ready = periph_ready;
            m_rdata = periph_rdata;
        end else begin
            m_ready = m_valid && hit_none;
            m_rdata = 32'h0000_0000;
        end
    end
endmodule
