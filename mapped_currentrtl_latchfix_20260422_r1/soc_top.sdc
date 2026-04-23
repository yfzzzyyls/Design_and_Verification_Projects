###################################################################

# Created by write_sdc on Wed Apr 22 18:55:42 2026

###################################################################
set sdc_version 2.1

set_units -time ns -resistance kOhm -capacitance pF -voltage V -current mA
set_driving_cell -lib_cell BUFFD1BWP16P90LVT [get_ports clk]
set_driving_cell -lib_cell BUFFD1BWP16P90LVT [get_ports rst_n]
set_driving_cell -lib_cell BUFFD1BWP16P90LVT [get_ports uart_rx]
set_load -pin_load 0.01 [get_ports uart_tx]
set_load -pin_load 0.01 [get_ports trap]
create_clock [get_ports clk]  -period 10  -waveform {0 5}
set_input_delay -clock clk  2  [get_ports rst_n]
set_input_delay -clock clk  2  [get_ports uart_rx]
set_output_delay -clock clk  2  [get_ports uart_tx]
set_output_delay -clock clk  2  [get_ports trap]
