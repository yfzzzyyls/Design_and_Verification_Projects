// SoC top: PicoRV32 with native SRAM and AXI4-Lite peripherals.
module soc_top #(
    parameter int MEM_WORDS = 32'd512
`ifndef SYNTHESIS
    , parameter string HEX_PATH = "firmware/cordic_test/cordic_test.hex"
`endif
) (
    input  logic clk,
    input  logic rst_n,
    input  logic uart_rx,
    output logic uart_tx,
    output logic trap
);

    // PicoRV32 native memory interface (master).
    logic        mem_valid;
    logic        mem_instr;
    logic        mem_ready;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [ 3:0] mem_wstrb;
    logic [31:0] mem_rdata;

    // To SRAM slave
    logic        sram_valid;
    logic        sram_instr;
    logic        sram_ready;
    logic [31:0] sram_addr;
    logic [31:0] sram_wdata;
    logic [ 3:0] sram_wstrb;
    logic [31:0] sram_rdata;

    // To peripheral bridge
    logic        periph_valid;
    logic        periph_instr;
    logic        periph_ready;
    logic [31:0] periph_addr;
    logic [31:0] periph_wdata;
    logic [ 3:0] periph_wstrb;
    logic [31:0] periph_rdata;

    // AXI4-Lite master from native peripheral bridge
    logic        m_axi_awvalid;
    logic        m_axi_awready;
    logic [31:0] m_axi_awaddr;
    logic [ 2:0] m_axi_awprot;
    logic        m_axi_wvalid;
    logic        m_axi_wready;
    logic [31:0] m_axi_wdata;
    logic [ 3:0] m_axi_wstrb;
    logic        m_axi_bvalid;
    logic        m_axi_bready;
    logic        m_axi_arvalid;
    logic        m_axi_arready;
    logic [31:0] m_axi_araddr;
    logic [ 2:0] m_axi_arprot;
    logic        m_axi_rvalid;
    logic        m_axi_rready;
    logic [31:0] m_axi_rdata;

    // AXI4-Lite UART slave
    logic        uart_axi_awvalid;
    logic        uart_axi_awready;
    logic [31:0] uart_axi_awaddr;
    logic [ 2:0] uart_axi_awprot;
    logic        uart_axi_wvalid;
    logic        uart_axi_wready;
    logic [31:0] uart_axi_wdata;
    logic [ 3:0] uart_axi_wstrb;
    logic        uart_axi_bvalid;
    logic        uart_axi_bready;
    logic        uart_axi_arvalid;
    logic        uart_axi_arready;
    logic [31:0] uart_axi_araddr;
    logic [ 2:0] uart_axi_arprot;
    logic        uart_axi_rvalid;
    logic        uart_axi_rready;
    logic [31:0] uart_axi_rdata;

    // AXI4-Lite CORDIC accelerator slave
    logic        cordic_axi_awvalid;
    logic        cordic_axi_awready;
    logic [31:0] cordic_axi_awaddr;
    logic [ 2:0] cordic_axi_awprot;
    logic        cordic_axi_wvalid;
    logic        cordic_axi_wready;
    logic [31:0] cordic_axi_wdata;
    logic [ 3:0] cordic_axi_wstrb;
    logic        cordic_axi_bvalid;
    logic        cordic_axi_bready;
    logic        cordic_axi_arvalid;
    logic        cordic_axi_arready;
    logic [31:0] cordic_axi_araddr;
    logic [ 2:0] cordic_axi_arprot;
    logic        cordic_axi_rvalid;
    logic        cordic_axi_rready;
    logic [31:0] cordic_axi_rdata;

    // Unused PicoRV32 ports
    logic        mem_la_read;
    logic        mem_la_write;
    logic [31:0] mem_la_addr;
    logic [31:0] mem_la_wdata;
    logic [ 3:0] mem_la_wstrb;

    logic        pcpi_valid;
    logic [31:0] pcpi_insn;
    logic [31:0] pcpi_rs1;
    logic [31:0] pcpi_rs2;

    logic        trace_valid;
    logic [35:0] trace_data;
    logic [31:0] eoi;

    localparam int STACKADDR = MEM_WORDS * 4;

    picorv32 #(
        .ENABLE_COUNTERS   (0),
        .ENABLE_COUNTERS64 (0),
        .ENABLE_REGS_16_31 (1),
        .ENABLE_REGS_DUALPORT(1),
        .LATCHED_MEM_RDATA (0),
        .TWO_STAGE_SHIFT   (1),
        .BARREL_SHIFTER    (0),
        .TWO_CYCLE_COMPARE (0),
        .TWO_CYCLE_ALU     (0),
        .COMPRESSED_ISA    (1),
        .CATCH_MISALIGN    (1),
        .CATCH_ILLINSN     (1),
        .ENABLE_PCPI       (0),
        .ENABLE_MUL        (1),
        .ENABLE_FAST_MUL   (1),
        .ENABLE_DIV        (1),
        .ENABLE_IRQ        (0),
        .ENABLE_IRQ_QREGS  (0),
        .ENABLE_IRQ_TIMER  (0),
        .ENABLE_TRACE      (0),
        .REGS_INIT_ZERO    (0),
        .MASKED_IRQ        (32'h0000_0000),
        .LATCHED_IRQ       (32'hffff_ffff),
        .PROGADDR_RESET    (32'h0000_0000),
        .STACKADDR         (STACKADDR)
    ) u_cpu (
        .clk         (clk),
        .resetn      (rst_n),
        .trap        (trap),
        .mem_valid   (mem_valid),
        .mem_instr   (mem_instr),
        .mem_ready   (mem_ready), // input
        .mem_addr    (mem_addr),  
        .mem_wdata   (mem_wdata),
        .mem_wstrb   (mem_wstrb),
        .mem_rdata   (mem_rdata), // input
        .mem_la_read (mem_la_read),
        .mem_la_write(mem_la_write),
        .mem_la_addr (mem_la_addr),
        .mem_la_wdata(mem_la_wdata),
        .mem_la_wstrb(mem_la_wstrb),
        .pcpi_valid  (pcpi_valid),
        .pcpi_insn   (pcpi_insn),
        .pcpi_rs1    (pcpi_rs1),
        .pcpi_rs2    (pcpi_rs2),
        .pcpi_wr     (1'b0),
        .pcpi_rd     (32'b0),
        .pcpi_wait   (1'b0),
        .pcpi_ready  (1'b0),
        .irq         (32'b0),
        .eoi         (eoi),
        .trace_valid (trace_valid),
        .trace_data  (trace_data)
    );

    mem_router_native #(
        .SRAM_BYTES      (MEM_WORDS * 4),
        .PERIPH_BASE_ADDR(32'h1000_0000),
        .PERIPH_BYTES    (32'd8192)
    ) u_mem_router (
        .m_valid   (mem_valid),
        .m_instr   (mem_instr),
        .m_ready   (mem_ready),
        .m_addr    (mem_addr),
        .m_wdata   (mem_wdata),
        .m_wstrb   (mem_wstrb),
        .m_rdata   (mem_rdata),
        .sram_valid(sram_valid),
        .sram_instr(sram_instr),
        .sram_ready(sram_ready),
        .sram_addr (sram_addr),
        .sram_wdata(sram_wdata),
        .sram_wstrb(sram_wstrb),
        .sram_rdata(sram_rdata),
        .periph_valid(periph_valid),
        .periph_instr(periph_instr),
        .periph_ready(periph_ready),
        .periph_addr (periph_addr),
        .periph_wdata(periph_wdata),
        .periph_wstrb(periph_wstrb),
        .periph_rdata(periph_rdata)
    );

    // SRAM slave
    sram #(
        .MEM_WORDS(MEM_WORDS)
    `ifndef SYNTHESIS
        , .HEX_PATH (HEX_PATH)
    `endif
    ) u_sram (
        .clk      (clk),
        .rst_n    (rst_n),
        .mem_valid(sram_valid),
        .mem_instr(sram_instr),
        .mem_ready(sram_ready),
        .mem_addr (sram_addr),
        .mem_wdata(sram_wdata),
        .mem_wstrb(sram_wstrb),
        .mem_rdata(sram_rdata)
    );

    native_periph_bridge u_periph_bridge (
        .clk          (clk),
        .rst_n        (rst_n),
        .mem_valid    (periph_valid),
        .mem_instr    (periph_instr),
        .mem_ready    (periph_ready),
        .mem_addr     (periph_addr),
        .mem_wdata    (periph_wdata),
        .mem_wstrb    (periph_wstrb),
        .mem_rdata    (periph_rdata),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_awaddr (m_axi_awaddr),
        .m_axi_awprot (m_axi_awprot),
        .m_axi_wvalid (m_axi_wvalid),
        .m_axi_wready (m_axi_wready),
        .m_axi_wdata  (m_axi_wdata),
        .m_axi_wstrb  (m_axi_wstrb),
        .m_axi_bvalid (m_axi_bvalid),
        .m_axi_bready (m_axi_bready),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_araddr (m_axi_araddr),
        .m_axi_arprot (m_axi_arprot),
        .m_axi_rvalid (m_axi_rvalid),
        .m_axi_rready (m_axi_rready),
        .m_axi_rdata  (m_axi_rdata)
    );

    axil_interconnect_1x2 u_axil_xbar (
        .clk              (clk),
        .rst_n            (rst_n),
        .s_axi_awvalid    (m_axi_awvalid),
        .s_axi_awready    (m_axi_awready),
        .s_axi_awaddr     (m_axi_awaddr),
        .s_axi_awprot     (m_axi_awprot),
        .s_axi_wvalid     (m_axi_wvalid),
        .s_axi_wready     (m_axi_wready),
        .s_axi_wdata      (m_axi_wdata),
        .s_axi_wstrb      (m_axi_wstrb),
        .s_axi_bvalid     (m_axi_bvalid),
        .s_axi_bready     (m_axi_bready),
        .s_axi_arvalid    (m_axi_arvalid),
        .s_axi_arready    (m_axi_arready),
        .s_axi_araddr     (m_axi_araddr),
        .s_axi_arprot     (m_axi_arprot),
        .s_axi_rvalid     (m_axi_rvalid),
        .s_axi_rready     (m_axi_rready),
        .s_axi_rdata      (m_axi_rdata),
        .uart_axi_awvalid (uart_axi_awvalid),
        .uart_axi_awready (uart_axi_awready),
        .uart_axi_awaddr  (uart_axi_awaddr),
        .uart_axi_awprot  (uart_axi_awprot),
        .uart_axi_wvalid  (uart_axi_wvalid),
        .uart_axi_wready  (uart_axi_wready),
        .uart_axi_wdata   (uart_axi_wdata),
        .uart_axi_wstrb   (uart_axi_wstrb),
        .uart_axi_bvalid  (uart_axi_bvalid),
        .uart_axi_bready  (uart_axi_bready),
        .uart_axi_arvalid (uart_axi_arvalid),
        .uart_axi_arready (uart_axi_arready),
        .uart_axi_araddr  (uart_axi_araddr),
        .uart_axi_arprot  (uart_axi_arprot),
        .uart_axi_rvalid  (uart_axi_rvalid),
        .uart_axi_rready  (uart_axi_rready),
        .uart_axi_rdata   (uart_axi_rdata),
        .cordic_axi_awvalid(cordic_axi_awvalid),
        .cordic_axi_awready(cordic_axi_awready),
        .cordic_axi_awaddr (cordic_axi_awaddr),
        .cordic_axi_awprot (cordic_axi_awprot),
        .cordic_axi_wvalid (cordic_axi_wvalid),
        .cordic_axi_wready (cordic_axi_wready),
        .cordic_axi_wdata  (cordic_axi_wdata),
        .cordic_axi_wstrb  (cordic_axi_wstrb),
        .cordic_axi_bvalid (cordic_axi_bvalid),
        .cordic_axi_bready (cordic_axi_bready),
        .cordic_axi_arvalid(cordic_axi_arvalid),
        .cordic_axi_arready(cordic_axi_arready),
        .cordic_axi_araddr (cordic_axi_araddr),
        .cordic_axi_arprot (cordic_axi_arprot),
        .cordic_axi_rvalid (cordic_axi_rvalid),
        .cordic_axi_rready (cordic_axi_rready),
        .cordic_axi_rdata  (cordic_axi_rdata)
    );

    axil_uart u_uart (
        .clk         (clk),
        .rst_n       (rst_n),
        .s_axi_awvalid(uart_axi_awvalid),
        .s_axi_awready(uart_axi_awready),
        .s_axi_awaddr (uart_axi_awaddr),
        .s_axi_awprot (uart_axi_awprot),
        .s_axi_wvalid (uart_axi_wvalid),
        .s_axi_wready (uart_axi_wready),
        .s_axi_wdata  (uart_axi_wdata),
        .s_axi_wstrb  (uart_axi_wstrb),
        .s_axi_bvalid (uart_axi_bvalid),
        .s_axi_bready (uart_axi_bready),
        .s_axi_arvalid(uart_axi_arvalid),
        .s_axi_arready(uart_axi_arready),
        .s_axi_araddr (uart_axi_araddr),
        .s_axi_arprot (uart_axi_arprot),
        .s_axi_rvalid (uart_axi_rvalid),
        .s_axi_rready (uart_axi_rready),
        .s_axi_rdata  (uart_axi_rdata),
        .uart_rx      (uart_rx),
        .uart_tx      (uart_tx)
    );

    axil_cordic_accel #(
        .WIDTH(32),
        .ITERATIONS(16)
    ) u_cordic_accel (
        .clk         (clk),
        .rst_n       (rst_n),
        .s_axi_awvalid(cordic_axi_awvalid),
        .s_axi_awready(cordic_axi_awready),
        .s_axi_awaddr (cordic_axi_awaddr),
        .s_axi_awprot (cordic_axi_awprot),
        .s_axi_wvalid (cordic_axi_wvalid),
        .s_axi_wready (cordic_axi_wready),
        .s_axi_wdata  (cordic_axi_wdata),
        .s_axi_wstrb  (cordic_axi_wstrb),
        .s_axi_bvalid (cordic_axi_bvalid),
        .s_axi_bready (cordic_axi_bready),
        .s_axi_arvalid(cordic_axi_arvalid),
        .s_axi_arready(cordic_axi_arready),
        .s_axi_araddr (cordic_axi_araddr),
        .s_axi_arprot (cordic_axi_arprot),
        .s_axi_rvalid (cordic_axi_rvalid),
        .s_axi_rready (cordic_axi_rready),
        .s_axi_rdata  (cordic_axi_rdata)
    );

endmodule
