module axil_uart #(
    parameter logic [31:0] DEFAULT_BAUD_DIV = 32'd7
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

    input  logic        uart_rx,
    output logic        uart_tx
);
    localparam logic [3:0] REG_TXDATA   = 4'h0;
    localparam logic [3:0] REG_RXDATA   = 4'h1;
    localparam logic [3:0] REG_STATUS   = 4'h2;
    localparam logic [3:0] REG_BAUD_DIV = 4'h3;
    localparam logic [3:0] REG_CTRL     = 4'h4;

    logic [31:0] baud_div_reg;
    logic [31:0] rxdata_reg;
    logic [31:0] rdata_reg;
    logic [31:0] ctrl_reg;
    logic        rx_valid;
    logic        uart_rx_meta;
    logic        uart_rx_sync;

    logic [ 9:0] tx_shift_reg;
    logic [ 3:0] tx_bits_remaining;
    logic [31:0] tx_baud_cnt;
    logic        tx_busy;
    logic        tx_ready;

    logic        write_fire;
    logic        read_fire;
    logic [ 3:0] write_addr_word;
    logic [ 3:0] read_addr_word;
    logic        write_ready;

    assign write_addr_word = s_axi_awaddr[5:2];
    assign read_addr_word  = s_axi_araddr[5:2];
    assign tx_ready        = ctrl_reg[0] && !tx_busy;
    assign write_ready     = !s_axi_bvalid && (!((write_addr_word == REG_TXDATA) && !tx_ready));
    assign write_fire      = s_axi_awvalid && s_axi_wvalid && write_ready;
    assign read_fire       = s_axi_arvalid && !s_axi_rvalid;

    assign s_axi_awready = s_axi_wvalid && write_ready;
    assign s_axi_wready  = s_axi_awvalid && write_ready;
    assign s_axi_arready = !s_axi_rvalid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_div_reg      <= DEFAULT_BAUD_DIV;
            rxdata_reg        <= 32'h0000_0000;
            ctrl_reg          <= 32'h0000_0001;
            rx_valid          <= 1'b0;
            uart_rx_meta      <= 1'b1;
            uart_rx_sync      <= 1'b1;
            s_axi_bvalid      <= 1'b0;
            s_axi_rvalid      <= 1'b0;
            rdata_reg         <= 32'h0000_0000;
            tx_shift_reg      <= 10'h3FF;
            tx_bits_remaining <= 4'd0;
            tx_baud_cnt       <= 32'h0000_0000;
            tx_busy           <= 1'b0;
        end else begin
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end

            if (write_fire) begin
                s_axi_bvalid <= 1'b1;
                case (write_addr_word)
                    REG_TXDATA: begin
                        if (ctrl_reg[0]) begin
                            tx_shift_reg      <= {1'b1, s_axi_wdata[7:0], 1'b0};
                            tx_bits_remaining <= 4'd10;
                            tx_baud_cnt       <= baud_div_reg;
                            tx_busy           <= 1'b1;
                        end
                    end
                    REG_BAUD_DIV: begin
                        if (s_axi_wstrb[0]) baud_div_reg[ 7:0] <= s_axi_wdata[ 7:0];
                        if (s_axi_wstrb[1]) baud_div_reg[15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) baud_div_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) baud_div_reg[31:24] <= s_axi_wdata[31:24];
                    end
                    REG_CTRL: begin
                        if (s_axi_wstrb[0]) ctrl_reg[ 7:0] <= s_axi_wdata[ 7:0];
                        if (s_axi_wstrb[1]) ctrl_reg[15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) ctrl_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) ctrl_reg[31:24] <= s_axi_wdata[31:24];
                    end
                    default: ;
                endcase
            end

            if (read_fire) begin
                s_axi_rvalid <= 1'b1;
                case (read_addr_word)
                    REG_TXDATA:   rdata_reg <= 32'h0000_0000;
                    REG_RXDATA:   rdata_reg <= rxdata_reg;
                    REG_STATUS:   rdata_reg <= {27'h0, tx_busy, ctrl_reg[1], ctrl_reg[0], rx_valid, tx_ready};
                    REG_BAUD_DIV: rdata_reg <= baud_div_reg;
                    REG_CTRL:     rdata_reg <= ctrl_reg;
                    default:      rdata_reg <= 32'h0000_0000;
                endcase
            end

            if (tx_busy) begin
                if (tx_baud_cnt == 32'd0) begin
                    tx_shift_reg <= {1'b1, tx_shift_reg[9:1]};
                    tx_baud_cnt  <= baud_div_reg;
                    if (tx_bits_remaining != 4'd0) begin
                        tx_bits_remaining <= tx_bits_remaining - 4'd1;
                    end
                    if (tx_bits_remaining == 4'd1) begin
                        tx_busy <= 1'b0;
                    end
                end else begin
                    tx_baud_cnt <= tx_baud_cnt - 32'd1;
                end
            end

            uart_rx_meta <= uart_rx;
            uart_rx_sync <= uart_rx_meta;
            if (ctrl_reg[1]) begin
                rxdata_reg[0] <= uart_rx_sync;
                rx_valid      <= 1'b1;
            end else begin
                rxdata_reg <= 32'h0000_0000;
                rx_valid   <= 1'b0;
            end
        end
    end

    assign uart_tx    = tx_busy ? tx_shift_reg[0] : 1'b1;
    assign s_axi_rdata = rdata_reg;

    // Unused protection bits in this minimal UART.
    logic unused_prot;
    assign unused_prot = ^{s_axi_awprot, s_axi_arprot};
endmodule
