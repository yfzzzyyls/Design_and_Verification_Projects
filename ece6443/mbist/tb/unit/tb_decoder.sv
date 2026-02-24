module tb_decoder;

logic [2:0] q;
logic [7:0] data_t;

decoder dut_decoder (.q(q), .data_t(data_t));

int errors = 0;

initial begin
    errors = 0;
    verify_decoder(3'b000, 8'b10101010);
    verify_decoder(3'b001, 8'b01010101);
    $display(errors==0 ? "PASS" : "FAIL errors=%0d", errors);
    $finish;
end

task automatic verify_decoder(
    input logic [2:0] sel,
    input logic [7:0] exp
);
begin
    q = sel;
    #1;
    if (data_t !== exp) begin
        $display("FAIL: q=%b exp=%b got=%b", sel, exp, data_t);
        errors++;
    end
end
endtask



endmodule