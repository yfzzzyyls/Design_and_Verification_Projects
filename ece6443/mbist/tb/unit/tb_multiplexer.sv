module tb_multiplexer;

logic       NbarT;
logic [7:0] normal_in;
logic [7:0] bist_in;
logic [7:0] out;

multiplexer dut_multiplexer (
    .NbarT(NbarT),
    .normal_in(normal_in),
    .bist_in(bist_in),
    .out(out)
);

int errors = 0;

initial begin
    errors = 0;

    // NbarT=0 => select normal_in
    verify_multiplexer(1'b0, 8'b10101010, 8'b01010101, 8'b10101010);
    verify_multiplexer(1'b0, 8'h00,     8'hFF,     8'h00);

    // NbarT=1 => select bist_in
    verify_multiplexer(1'b1, 8'b10101010, 8'b01010101, 8'b01010101);
    verify_multiplexer(1'b1, 8'h00,       8'hFF,       8'hFF);

    $display(errors==0 ? "PASS" : "FAIL errors=%0d", errors);
    $finish;
end

task automatic verify_multiplexer(
    input logic       sel,
    input logic [7:0] n_in,
    input logic [7:0] b_in,
    input logic [7:0] exp
);
begin
    NbarT     = sel;
    normal_in = n_in;
    bist_in   = b_in;
    #1;
    if (out !== exp) begin
        $display("FAIL: NbarT=%b normal_in=%b bist_in=%b exp=%b got=%b",
                 sel, n_in, b_in, exp, out);
        errors++;
    end
end
endtask

endmodule
