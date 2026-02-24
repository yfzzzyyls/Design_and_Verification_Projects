module tb_comparator;

logic [7:0] data_t;
logic [7:0] ramout;
logic       gt;
logic       eq;
logic       lt;

comparator dut_comparator (
    .data_t(data_t),
    .ramout(ramout),
    .gt(gt),
    .eq(eq),
    .lt(lt)
);

int errors = 0;

initial begin
    errors = 0;

    // data_t > ramout
    verify_comparator(8'hAA, 8'h55, 1'b1, 1'b0, 1'b0);

    // data_t == ramout
    verify_comparator(8'h3C, 8'h3C, 1'b0, 1'b1, 1'b0);

    // data_t < ramout
    verify_comparator(8'h10, 8'hF0, 1'b0, 1'b0, 1'b1);

    // boundary checks
    verify_comparator(8'h00, 8'hFF, 1'b0, 1'b0, 1'b1);
    verify_comparator(8'hFF, 8'h00, 1'b1, 1'b0, 1'b0);
    verify_comparator(8'h00, 8'h00, 1'b0, 1'b1, 1'b0);
    verify_comparator(8'hFF, 8'hFF, 1'b0, 1'b1, 1'b0);

    $display(errors==0 ? "PASS" : "FAIL errors=%0d", errors);
    $finish;
end

task automatic verify_comparator(
    input logic [7:0] in_data_t,
    input logic [7:0] in_ramout,
    input logic       exp_gt,
    input logic       exp_eq,
    input logic       exp_lt
);
begin
    data_t = in_data_t;
    ramout = in_ramout;
    #1;
    if (gt !== exp_gt || eq !== exp_eq || lt !== exp_lt) begin
        $display("FAIL: data_t=%h ramout=%h exp(gt,eq,lt)=%b%b%b got=%b%b%b",
                 in_data_t, in_ramout, exp_gt, exp_eq, exp_lt, gt, eq, lt);
        errors++;
    end
end
endtask

endmodule
