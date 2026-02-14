// ============================================================================
//  64 × 8 Single‑Port SRAM (behavioural model)
// ----------------------------------------------------------------------------
//  • Synchronous write on rising edge when cs=1 and rwbar=0
//  • Registered address for read; data available next cycle
//  • Zero output when cs=0 (tri‑state not modelled)
//  • Parameterised DATA_W and ADDR_W to stay reusable
// ============================================================================

module sram #(
    parameter int DATA_W = 8,
    parameter int ADDR_W = 6               // 2^6 = 64 locations
)(
    input  logic                  clk,
    input  logic                  cs,      // chip‑select, active‑high
    input  logic                  rwbar,   // 0 = write, 1 = read
    input  logic [ADDR_W-1:0]     ramaddr,
    input  logic [DATA_W-1:0]     ramin,
    output logic [DATA_W-1:0]     ramout
);

    // ---------------------------------------------------------------------
    // Memory array and address register
    // ---------------------------------------------------------------------
    logic [DATA_W-1:0] mem [0:(1<<ADDR_W)-1];
    logic [ADDR_W-1:0] addr_reg;

    // ---------------------------------------------------------------------
    // Sequential write and address capture
    // ---------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (cs) begin
            addr_reg <= ramaddr;           // register address for read path
            if (!rwbar)                    // write
                mem[ramaddr] <= ramin;
        end
    end

    // ---------------------------------------------------------------------
    // Combinational read (latched address)
    // ---------------------------------------------------------------------
    always_comb begin
        if (cs && rwbar)
            ramout = mem[addr_reg];
        else
            ramout = '0;                   // drive zeros when disabled
    end

endmodule