module cordic_accel_ctrl #(
    parameter int WIDTH      = 32,
    parameter int ITERATIONS = 16
) (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    start,
    input  logic                    soft_reset,
    input  logic                    clear_done,
    input  logic                    clear_error,
    input  logic [31:0]             opcode,
    input  logic signed [WIDTH-1:0] x_reg,
    input  logic signed [WIDTH-1:0] y_reg,
    input  logic signed [WIDTH-1:0] angle_reg,
    output logic                    idle,
    output logic                    busy,
    output logic                    done,
    output logic                    error,
    output logic [31:0]             error_code,
    output logic signed [WIDTH-1:0] result0,
    output logic signed [WIDTH-1:0] result1
);
    localparam logic [31:0] OPCODE_ATAN2  = 32'd0;
    localparam logic [31:0] OPCODE_SINCOS = 32'd1;
    localparam logic [31:0] ERR_NONE      = 32'd0;
    localparam logic [31:0] ERR_BUSY      = 32'd1;
    localparam logic [31:0] ERR_OPCODE    = 32'd2;

    logic launch_atan2;
    logic launch_sincos;
    logic atan2_valid_out;
    logic sincos_valid_out;
    logic signed [WIDTH-1:0] atan2_phase;
    logic signed [WIDTH-1:0] sincos_cos;
    logic signed [WIDTH-1:0] sincos_sin;

    assign launch_atan2  = start && !busy && (opcode == OPCODE_ATAN2);
    assign launch_sincos = start && !busy && (opcode == OPCODE_SINCOS);
    assign idle          = !busy;

    cordic_core_atan2 #(
        .WIDTH     (WIDTH),
        .ITERATIONS(ITERATIONS)
    ) u_core_atan2 (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (launch_atan2),
        .x_in     (x_reg),
        .y_in     (y_reg),
        .valid_out(atan2_valid_out),
        .phase_out(atan2_phase)
    );

    cordic_core_sincos #(
        .WIDTH     (WIDTH),
        .ITERATIONS(ITERATIONS)
    ) u_core_sincos (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (launch_sincos),
        .angle_in (angle_reg),
        .valid_out(sincos_valid_out),
        .cos_out  (sincos_cos),
        .sin_out  (sincos_sin)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy       <= 1'b0;
            done       <= 1'b0;
            error      <= 1'b0;
            error_code <= ERR_NONE;
            result0    <= '0;
            result1    <= '0;
        end else begin
            if (soft_reset) begin
                busy       <= 1'b0;
                done       <= 1'b0;
                error      <= 1'b0;
                error_code <= ERR_NONE;
                result0    <= '0;
                result1    <= '0;
            end else begin
                if (clear_done) begin
                    done <= 1'b0;
                end
                if (clear_error) begin
                    error      <= 1'b0;
                    error_code <= ERR_NONE;
                end

                if (start) begin
                    done <= 1'b0;
                    if (busy) begin
                        error      <= 1'b1;
                        error_code <= ERR_BUSY;
                    end else if (!(launch_atan2 || launch_sincos)) begin
                        error      <= 1'b1;
                        error_code <= ERR_OPCODE;
                    end else begin
                        busy       <= 1'b1;
                        error      <= 1'b0;
                        error_code <= ERR_NONE;
                    end
                end

                if (atan2_valid_out) begin
                    busy    <= 1'b0;
                    done    <= 1'b1;
                    result0 <= atan2_phase;
                    result1 <= '0;
                end

                if (sincos_valid_out) begin
                    busy    <= 1'b0;
                    done    <= 1'b1;
                    result0 <= sincos_cos;
                    result1 <= sincos_sin;
                end
            end
        end
    end
endmodule
