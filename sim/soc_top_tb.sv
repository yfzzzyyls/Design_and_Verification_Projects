`timescale 1ns/1ps

module soc_top_tb;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic uart_rx = 1'b1;
    logic uart_tx;
    logic trap;

    localparam int UART_BIT_CLKS = 8;

    // 100 MHz clock
    always #5 clk = ~clk;

    // Deassert reset after a few cycles
    initial begin
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
    end

    soc_top #(
        .MEM_WORDS(512),
        .HEX_PATH("firmware/cordic_test/cordic_test.hex")
    ) dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .trap   (trap)
    );

    initial begin : uart_monitor
        byte rx_byte;
        forever begin
            @(negedge uart_tx);
            repeat (UART_BIT_CLKS/2) @(posedge clk);
            if (uart_tx !== 1'b0) begin
                continue;
            end
            for (int bit_idx = 0; bit_idx < 8; bit_idx++) begin
                repeat (UART_BIT_CLKS) @(posedge clk);
                rx_byte[bit_idx] = uart_tx;
            end
            repeat (UART_BIT_CLKS) @(posedge clk);
            $write("%c", rx_byte);
        end
    end

    initial begin : monitor
        int cycles = 0;
        wait (rst_n);
        forever begin
            @(posedge clk);
            cycles++;
            if (trap) begin
                $display("[%0t] Firmware completed after %0d cycles. PASS", $time, cycles);
                $finish;
            end
            if (cycles > 200_000) begin
                $fatal(1, "[%0t] Timeout waiting for trap. FAIL", $time);
            end
        end
    end
endmodule
