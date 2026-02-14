# create_clock -period 120.0 -name clk [get_ports clk]
# set_input_delay 0.1 -clock clk [all_inputs]
# set_output_delay 0.15 -clock clk [all_outputs]
# set_load 0.1 [all_outputs]
# set_max_fanout 1 [all_inputs]
# set_fanout_load 8 [all_outputs]
# set_clock_uncertainty .01 [all_clocks ]
# set_clock_latency 0.01 -source [get_ports clk]



# ------------------------------------------------------------------
# Top‑level SDC for MBIST project — tightened for ~6 ns clock period
# Requirement: positive slack < 5 ns
# ------------------------------------------------------------------

# 1) Clock definition: 166 MHz (6 ns period)
create_clock -name clk -period 6.0 [get_ports clk]

# 2) Clock uncertainties (jitter + skew)
set_clock_uncertainty 0.10 [all_clocks]          ;# 100 ps

# 3) Clock source latency (board + clk tree estimate)
set_clock_latency 0.05 -source [get_ports clk]   ;# 50 ps

# 4) I/O timing budgets (capture some board delay)
set_input_delay  0.50 -clock clk [all_inputs]
set_output_delay 0.50 -clock clk [all_outputs]

# 5) Loading & fan‑out guidelines
set_load        0.10 [all_outputs]
set_max_fanout  1    [all_inputs]
set_fanout_load 8    [all_outputs]