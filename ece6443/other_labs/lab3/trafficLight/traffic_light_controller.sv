module traffic_light_controller (
    input logic clk, reset,
    output logic [1:0] light_NS, light_EW  // 00 = Red, 01 = Yellow, 10 = Green
);
   //declare your enum here, enum name should be "state_e"
    typedef enum logic [2:0] {
        S0, // ALL_RED
        S1, // NS_GREEN_EW_RED
        S2, // NS_YELLOW_EW_RED
        S3, // EW_GREEN_NS_RED
        S4  // EW_YELLOW_NS_RED
    } state_e;
   //create two variables called "state" and "next" of enumeration type
    state_e state, next;
    // 3) Synchronous process: on posedge clk or posedge reset
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // As soon as reset is high, force both lights to Red (S0)
            state <= S0;
        end
        else begin
            // Otherwise, update to the calculated next state
            state <= next;
        end
    end
    // 4) Combinational block: next-state logic
    always_comb begin
        // Default to staying in the same state
        next = state;
        case (state)
            S0:  next = S1; // After ALL_RED, go to NS Green
            S1:  next = S2; // NS Green -> NS Yellow
            S2:  next = S3; // NS Yellow -> EW Green
            S3:  next = S4; // EW Green -> EW Yellow
            S4:  next = S1; // EW Yellow -> NS Green (repeat)
            default: next = S0;
        endcase
    end
    // 5) Combinational block: output logic
    always_comb begin
        // Default all outputs to Red unless overridden
        light_NS = 2'b00; // Red
        light_EW = 2'b00; // Red
        case (state)
            // S0: ALL_RED
            S0: begin
                light_NS = 2'b00; // Red
                light_EW = 2'b00; // Red
            end
            // S1: NS Green, EW Red
            S1: begin
                light_NS = 2'b10; // Green
                light_EW = 2'b00; // Red
            end
            // S2: NS Yellow, EW Red
            S2: begin
                light_NS = 2'b01; // Yellow
                light_EW = 2'b00; // Red
            end
            // S3: NS Red, EW Green
            S3: begin
                light_NS = 2'b00; // Red
                light_EW = 2'b10; // Green
            end
            // S4: NS Red, EW Yellow
            S4: begin
                light_NS = 2'b00; // Red
                light_EW = 2'b01; // Yellow
            end
            default: begin
                // Should never reach here, but keep safe
                light_NS = 2'b00;
                light_EW = 2'b00;
            end
        endcase
    end
endmodule