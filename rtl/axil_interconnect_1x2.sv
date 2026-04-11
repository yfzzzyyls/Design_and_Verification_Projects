module axil_interconnect_1x2 #(
    parameter logic [31:0] UART_BASE_ADDR   = 32'h1000_0000,
    parameter logic [31:0] CORDIC_BASE_ADDR = 32'h1000_1000
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    input  logic [31:0] s_axi_awaddr,
    input  logic [ 2:0] s_axi_awprot,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    input  logic [31:0] s_axi_wdata,
    input  logic [ 3:0] s_axi_wstrb,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    input  logic [31:0] s_axi_araddr,
    input  logic [ 2:0] s_axi_arprot,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,
    output logic [31:0] s_axi_rdata,

    output logic        uart_axi_awvalid,
    input  logic        uart_axi_awready,
    output logic [31:0] uart_axi_awaddr,
    output logic [ 2:0] uart_axi_awprot,
    output logic        uart_axi_wvalid,
    input  logic        uart_axi_wready,
    output logic [31:0] uart_axi_wdata,
    output logic [ 3:0] uart_axi_wstrb,
    input  logic        uart_axi_bvalid,
    output logic        uart_axi_bready,
    output logic        uart_axi_arvalid,
    input  logic        uart_axi_arready,
    output logic [31:0] uart_axi_araddr,
    output logic [ 2:0] uart_axi_arprot,
    input  logic        uart_axi_rvalid,
    output logic        uart_axi_rready,
    input  logic [31:0] uart_axi_rdata,

    output logic        cordic_axi_awvalid,
    input  logic        cordic_axi_awready,
    output logic [31:0] cordic_axi_awaddr,
    output logic [ 2:0] cordic_axi_awprot,
    output logic        cordic_axi_wvalid,
    input  logic        cordic_axi_wready,
    output logic [31:0] cordic_axi_wdata,
    output logic [ 3:0] cordic_axi_wstrb,
    input  logic        cordic_axi_bvalid,
    output logic        cordic_axi_bready,
    output logic        cordic_axi_arvalid,
    input  logic        cordic_axi_arready,
    output logic [31:0] cordic_axi_araddr,
    output logic [ 2:0] cordic_axi_arprot,
    input  logic        cordic_axi_rvalid,
    output logic        cordic_axi_rready,
    input  logic [31:0] cordic_axi_rdata
);
    logic write_sel_uart;
    logic write_sel_cordic;
    logic read_sel_uart;
    logic read_sel_cordic;

    logic invalid_bvalid;
    logic invalid_rvalid;
    logic [31:0] invalid_rdata;

    assign write_sel_uart   = (s_axi_awaddr[31:12] == UART_BASE_ADDR[31:12]);
    assign write_sel_cordic = (s_axi_awaddr[31:12] == CORDIC_BASE_ADDR[31:12]);
    assign read_sel_uart    = (s_axi_araddr[31:12] == UART_BASE_ADDR[31:12]);
    assign read_sel_cordic  = (s_axi_araddr[31:12] == CORDIC_BASE_ADDR[31:12]);

    assign uart_axi_awvalid = s_axi_awvalid && write_sel_uart;
    assign uart_axi_awaddr  = s_axi_awaddr;
    assign uart_axi_awprot  = s_axi_awprot;
    assign uart_axi_wvalid  = s_axi_wvalid && write_sel_uart;
    assign uart_axi_wdata   = s_axi_wdata;
    assign uart_axi_wstrb   = s_axi_wstrb;
    assign uart_axi_arvalid = s_axi_arvalid && read_sel_uart;
    assign uart_axi_araddr  = s_axi_araddr;
    assign uart_axi_arprot  = s_axi_arprot;

    assign cordic_axi_awvalid = s_axi_awvalid && write_sel_cordic;
    assign cordic_axi_awaddr  = s_axi_awaddr;
    assign cordic_axi_awprot  = s_axi_awprot;
    assign cordic_axi_wvalid  = s_axi_wvalid && write_sel_cordic;
    assign cordic_axi_wdata   = s_axi_wdata;
    assign cordic_axi_wstrb   = s_axi_wstrb;
    assign cordic_axi_arvalid = s_axi_arvalid && read_sel_cordic;
    assign cordic_axi_araddr  = s_axi_araddr;
    assign cordic_axi_arprot  = s_axi_arprot;

    assign uart_axi_bready   = s_axi_bready;
    assign cordic_axi_bready = s_axi_bready;
    assign uart_axi_rready   = s_axi_rready;
    assign cordic_axi_rready = s_axi_rready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            invalid_bvalid <= 1'b0;
            invalid_rvalid <= 1'b0;
            invalid_rdata  <= 32'h0000_0000;
        end else begin
            if (!invalid_bvalid &&
                s_axi_awvalid && s_axi_wvalid &&
                !(write_sel_uart || write_sel_cordic)) begin
                invalid_bvalid <= 1'b1;
            end else if (invalid_bvalid && s_axi_bready) begin
                invalid_bvalid <= 1'b0;
            end

            if (!invalid_rvalid && s_axi_arvalid &&
                !(read_sel_uart || read_sel_cordic)) begin
                invalid_rvalid <= 1'b1;
                invalid_rdata  <= 32'h0000_0000;
            end else if (invalid_rvalid && s_axi_rready) begin
                invalid_rvalid <= 1'b0;
            end
        end
    end

    always_comb begin
        if (write_sel_uart) begin
            s_axi_awready = uart_axi_awready;
            s_axi_wready  = uart_axi_wready;
        end else if (write_sel_cordic) begin
            s_axi_awready = cordic_axi_awready;
            s_axi_wready  = cordic_axi_wready;
        end else begin
            s_axi_awready = s_axi_wvalid && !invalid_bvalid;
            s_axi_wready  = s_axi_awvalid && !invalid_bvalid;
        end

        if (read_sel_uart) begin
            s_axi_arready = uart_axi_arready;
        end else if (read_sel_cordic) begin
            s_axi_arready = cordic_axi_arready;
        end else begin
            s_axi_arready = !invalid_rvalid;
        end

        if (uart_axi_bvalid) begin
            s_axi_bvalid = 1'b1;
        end else if (cordic_axi_bvalid) begin
            s_axi_bvalid = 1'b1;
        end else begin
            s_axi_bvalid = invalid_bvalid;
        end

        if (uart_axi_rvalid) begin
            s_axi_rvalid = 1'b1;
            s_axi_rdata  = uart_axi_rdata;
        end else if (cordic_axi_rvalid) begin
            s_axi_rvalid = 1'b1;
            s_axi_rdata  = cordic_axi_rdata;
        end else begin
            s_axi_rvalid = invalid_rvalid;
            s_axi_rdata  = invalid_rdata;
        end
    end
endmodule
