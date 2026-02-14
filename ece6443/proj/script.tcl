define_design_lib WORK -path ./work 

set PDK_DIR /ip/synopsys/saed32/v02_2024/lib
set_app_var search_path "$PDK_DIR/stdcell_lvt/db_nldm ./rtl ./"

set_app_var target_library "saed32lvt_ss0p75v125c.db"
set_app_var link_library "* $target_library"

read_file {decoder.sv multiplexer.sv sram.sv controller.sv comparator.sv counter.sv bist.sv} -autoread -format sverilog -top bist

elaborate bist
read_sdc constraint.sdc
link
compile_ultra
#compile

report_timing > timing.rpt
report_area > area.rpt
report_power > power.rpt
