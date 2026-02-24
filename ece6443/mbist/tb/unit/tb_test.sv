`timescale 1ns/1ps

module tb_counter;

localparam int LENGTH = 10;

logic              clk;
logic              cen;
logic              ld;
logic              u_d;
logic [LENGTH-1:0] d_in;
logic [LENGTH-1:0] q;
logic              cout;

int errors = 0;

// DUT
counter #(.length(LENGTH)) dut_counter (
    .clk(clk),
    .cen(cen),
    .ld(ld),
    .u_d(u_d),
    .d_in(d_in),
    .q(q),
    .cout(cout)
);

// clock
always #5 clk = ~clk;

task automatic check_state(
    input logic [LENGTH-1:0] exp_q,
    input logic              exp_cout,
    input string             tag
);
begin
    if ((q !== exp_q) || (cout !== exp_cout)) begin
        $display("FAIL [%s] t=%0t exp_q=%0d exp_cout=%b got_q=%0d got_cout=%b",
                 tag, $time, exp_q, exp_cout, q, cout);
        errors++;
    end
end
endtask

task automatic do_load(input logic [LENGTH-1:0] val);
begin
    cen  = 1'b1;
    ld   = 1'b1;
    u_d  = 1'b0; // don't care when ld=1
    d_in = val;
    @(posedge clk);
    #1;
end
endtask

task automatic do_count(input logic dir_up);
begin
    cen  = 1'b1;
    ld   = 1'b0;
    u_d  = dir_up;
    @(posedge clk);
    #1;
end
endtask

initial begin
    // init
    clk  = 1'b0;
    cen  = 1'b0;
    ld   = 1'b0;
    u_d  = 1'b0;
    d_in = '0;
    errors = 0;
    #1;

    // 1) Load (also checks load priority behavior)
    do_load(10'd5);
    check_state(10'd5, 1'b0, "load 5");

    // 2) Count up
    do_count(1'b1);
    check_state(10'd6, 1'b0, "count up");

    // 3) Count down
    do_count(1'b0);
    check_state(10'd5, 1'b0, "count down");

    // 4) Hold when cen=0
    cen = 1'b0;
    ld  = 1'b0;
    u_d = 1'b1;
    repeat (2) @(posedge clk);
    #1;
    check_state(10'd5, 1'b0, "hold when cen=0");

    // 5) Terminal up detect (cout high at max before edge)
    do_load({LENGTH{1'b1}});
    check_state({LENGTH{1'b1}}, 1'b0, "load max");

    cen = 1'b1;
    ld  = 1'b0;
    u_d = 1'b1;
    #1;
    check_state({LENGTH{1'b1}}, 1'b1, "cout high at max");

    @(posedge clk);
    #1;
    check_state('0, 1'b0, "wrap after max+1");

    // 6) Terminal down detect (cout high at zero before edge)
    do_load('0);
    check_state('0, 1'b0, "load zero");

    cen = 1'b1;
    ld  = 1'b0;
    u_d = 1'b0;
    #1;
    check_state('0, 1'b1, "cout high at zero");

    @(posedge clk);
    #1;
    check_state({LENGTH{1'b1}}, 1'b0, "wrap after 0-1");

    $display(errors == 0 ? "PASS" : "FAIL errors=%0d", errors);
    $finish;
end

endmodule
