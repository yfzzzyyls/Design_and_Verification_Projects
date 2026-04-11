module axil_cordic_accel #(
    parameter int WIDTH      = 32,
    parameter int ITERATIONS = 16
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
    output logic [31:0] s_axi_rdata
);
    localparam logic [5:0] REG_ID_VERSION = 6'h00;
    localparam logic [5:0] REG_CONTROL    = 6'h01;
    localparam logic [5:0] REG_STATUS     = 6'h02;
    localparam logic [5:0] REG_OPCODE     = 6'h03;
    localparam logic [5:0] REG_X          = 6'h04;
    localparam logic [5:0] REG_Y          = 6'h05;
    localparam logic [5:0] REG_ANGLE      = 6'h06;
    localparam logic [5:0] REG_RESULT0    = 6'h07;
    localparam logic [5:0] REG_RESULT1    = 6'h08;

    localparam logic [31:0] ID_VERSION = 32'h434F_5244;

    logic [31:0] opcode_reg;
    logic signed [WIDTH-1:0] x_reg;
    logic signed [WIDTH-1:0] y_reg;
    logic signed [WIDTH-1:0] angle_reg;
    logic [31:0] rdata_reg;

    logic        write_fire;
    logic        read_fire;
    logic [ 5:0] write_addr_word;
    logic [ 5:0] read_addr_word;
    logic        start_pulse;
    logic        soft_reset_pulse;

    logic        idle;
    logic        busy;
    logic        done;
    logic        error;
    logic signed [WIDTH-1:0] result0;
    logic signed [WIDTH-1:0] result1;

    assign write_addr_word = s_axi_awaddr[7:2];
    assign read_addr_word  = s_axi_araddr[7:2];
    assign write_fire      = s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid;
    assign read_fire       = s_axi_arvalid && !s_axi_rvalid;

    assign s_axi_awready = s_axi_wvalid && !s_axi_bvalid;
    assign s_axi_wready  = s_axi_awvalid && !s_axi_bvalid;
    assign s_axi_arready = !s_axi_rvalid;

    cordic_accel_ctrl #(
        .WIDTH     (WIDTH),
        .ITERATIONS(ITERATIONS)
    ) u_cordic_ctrl (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start_pulse),
        .soft_reset(soft_reset_pulse),
        .opcode    (opcode_reg),
        .x_reg     (x_reg),
        .y_reg     (y_reg),
        .angle_reg (angle_reg),
        .idle      (idle),
        .busy      (busy),
        .done      (done),
        .error     (error),
        .result0   (result0),
        .result1   (result1)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            opcode_reg       <= 32'h0000_0000;
            x_reg            <= '0;
            y_reg            <= '0;
            angle_reg        <= '0;
            rdata_reg        <= 32'h0000_0000;
            s_axi_bvalid     <= 1'b0;
            s_axi_rvalid     <= 1'b0;
            start_pulse      <= 1'b0;
            soft_reset_pulse <= 1'b0;
        end else begin
            start_pulse      <= 1'b0;
            soft_reset_pulse <= 1'b0;

            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end

            if (write_fire) begin
                s_axi_bvalid <= 1'b1;
                case (write_addr_word)
                    REG_CONTROL: begin
                        start_pulse      <= s_axi_wstrb[0] && s_axi_wdata[0];
                        soft_reset_pulse <= s_axi_wstrb[0] && s_axi_wdata[1];
                    end
                    REG_OPCODE: begin
                        if (s_axi_wstrb[0]) opcode_reg[ 7:0] <= s_axi_wdata[ 7:0];
                        if (s_axi_wstrb[1]) opcode_reg[15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) opcode_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) opcode_reg[31:24] <= s_axi_wdata[31:24];
                    end
                    REG_X: begin
                        if (s_axi_wstrb[0]) x_reg[ 7:0] <= s_axi_wdata[ 7:0];
                        if (s_axi_wstrb[1]) x_reg[15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) x_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) x_reg[31:24] <= s_axi_wdata[31:24];
                    end
                    REG_Y: begin
                        if (s_axi_wstrb[0]) y_reg[ 7:0] <= s_axi_wdata[ 7:0];
                        if (s_axi_wstrb[1]) y_reg[15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) y_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) y_reg[31:24] <= s_axi_wdata[31:24];
                    end
                    REG_ANGLE: begin
                        if (s_axi_wstrb[0]) angle_reg[ 7:0] <= s_axi_wdata[ 7:0];
                        if (s_axi_wstrb[1]) angle_reg[15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) angle_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) angle_reg[31:24] <= s_axi_wdata[31:24];
                    end
                    default: ;
                endcase
            end

            if (read_fire) begin
                s_axi_rvalid <= 1'b1;
                case (read_addr_word)
                    REG_ID_VERSION: rdata_reg <= ID_VERSION;
                    REG_CONTROL:    rdata_reg <= 32'h0000_0000;
                    REG_STATUS:     rdata_reg <= {28'h0, error, done, busy, idle};
                    REG_OPCODE:     rdata_reg <= opcode_reg;
                    REG_X:          rdata_reg <= x_reg;
                    REG_Y:          rdata_reg <= y_reg;
                    REG_ANGLE:      rdata_reg <= angle_reg;
                    REG_RESULT0:    rdata_reg <= result0;
                    REG_RESULT1:    rdata_reg <= result1;
                    default:        rdata_reg <= 32'h0000_0000;
                endcase
            end
        end
    end

    assign s_axi_rdata = rdata_reg;

    logic unused_prot;
    assign unused_prot = ^{s_axi_awprot, s_axi_arprot};
endmodule
