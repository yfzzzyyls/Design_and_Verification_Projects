module jcounter(
    input logic [3:0] D,
    input logic clk, rst
)

always_ff @(posedge clock ) begin
    if (rst) D <= '0;
    else begin
        d[0] <= ~D[3];
        d[1] <= ~D[0];
        d[2] <= ~D[1];
        d[3] <= ~D[2];
    end
end

endmodule
