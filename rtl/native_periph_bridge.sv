module native_periph_bridge (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        mem_valid,
    input  logic        mem_instr,
    output logic        mem_ready,
    input  logic [31:0] mem_addr,
    input  logic [31:0] mem_wdata,
    input  logic [ 3:0] mem_wstrb,
    output logic [31:0] mem_rdata,

    output logic        m_axi_awvalid,
    input  logic        m_axi_awready,
    output logic [31:0] m_axi_awaddr,
    output logic [ 2:0] m_axi_awprot,

    output logic        m_axi_wvalid,
    input  logic        m_axi_wready,
    output logic [31:0] m_axi_wdata,
    output logic [ 3:0] m_axi_wstrb,

    input  logic        m_axi_bvalid,
    output logic        m_axi_bready,

    output logic        m_axi_arvalid,
    input  logic        m_axi_arready,
    output logic [31:0] m_axi_araddr,
    output logic [ 2:0] m_axi_arprot,

    input  logic        m_axi_rvalid,
    output logic        m_axi_rready,
    input  logic [31:0] m_axi_rdata
);
    picorv32_axi_adapter u_axi_adapter (
        .clk            (clk),
        .resetn         (rst_n),
        .mem_axi_awvalid(m_axi_awvalid),
        .mem_axi_awready(m_axi_awready),
        .mem_axi_awaddr (m_axi_awaddr),
        .mem_axi_awprot (m_axi_awprot),
        .mem_axi_wvalid (m_axi_wvalid),
        .mem_axi_wready (m_axi_wready),
        .mem_axi_wdata  (m_axi_wdata),
        .mem_axi_wstrb  (m_axi_wstrb),
        .mem_axi_bvalid (m_axi_bvalid),
        .mem_axi_bready (m_axi_bready),
        .mem_axi_arvalid(m_axi_arvalid),
        .mem_axi_arready(m_axi_arready),
        .mem_axi_araddr (m_axi_araddr),
        .mem_axi_arprot (m_axi_arprot),
        .mem_axi_rvalid (m_axi_rvalid),
        .mem_axi_rready (m_axi_rready),
        .mem_axi_rdata  (m_axi_rdata),
        .mem_valid      (mem_valid),
        .mem_instr      (mem_instr),
        .mem_ready      (mem_ready),
        .mem_addr       (mem_addr),
        .mem_wdata      (mem_wdata),
        .mem_wstrb      (mem_wstrb),
        .mem_rdata      (mem_rdata)
    );
endmodule
