module traffic_light_controller_tb;
    logic clk, reset;
    logic [1:0] light_NS, light_EW;
    // DUT Instantiation
    traffic_light_controller dut (
        .clk      (clk),
        .reset    (reset),
        .light_NS (light_NS),
        .light_EW (light_EW)
    );
    // Clock Generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;  // 10 ns period
    end
    // Because this traffic light FSM is purely automatic, we just
    // observe outputs after each clock, ensuring it follows the sequence:
    //   S0 (ALL_RED) -> S1 (NS_GREEN) -> S2 (NS_YELLOW) ->
    //   S3 (EW_GREEN) -> S4 (EW_YELLOW) -> back to S1...
    initial begin
        // Initialize
        reset = 1'b0;
        // 1) Assert reset (active-high) for a few cycles
        #8 reset = 1'b1;  
        @(posedge clk);
        // Expect S0: (NS=00, EW=00)
        check_outputs(2'b00, 2'b00);
        // 2) Deassert reset
        #1 reset = 1'b0;
        // On the next rising clock, S0 -> S1
        // For each transition, we wait one clock, then check outputs.
        // S1: NS=10, EW=00
        @(posedge clk);
        check_outputs(2'b10, 2'b00);
        // S2: NS=01, EW=00
        @(posedge clk);
        check_outputs(2'b01, 2'b00);
        // S3: NS=00, EW=10
        @(posedge clk);
        check_outputs(2'b00, 2'b10);
        // S4: NS=00, EW=01
        @(posedge clk);
        check_outputs(2'b00, 2'b01);
        // Back to S1
        @(posedge clk);
        check_outputs(2'b10, 2'b00);
        // If we reach here, no mismatch was found => PASS once
        $display("PASS");
        $finish;
    end
    // check_outputs task
    // If mismatch => print FAIL and finish
    task check_outputs(
        input logic [1:0] exp_ns,
        input logic [1:0] exp_ew
    );
        // Small delay to allow outputs to settle
        #1;
        if (light_NS !== exp_ns || light_EW !== exp_ew) begin
            $display("FAIL");
            $finish;
        end
    endtask
endmodule