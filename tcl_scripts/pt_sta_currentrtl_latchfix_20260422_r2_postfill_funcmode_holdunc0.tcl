set out_dir   "/home/fy2243/soc_design/sta/currentrtl_latchfix_20260422_r2_postfill/primetime_funcmode_holdunc0"
set in_dir    "/home/fy2243/soc_design/sta/currentrtl_latchfix_20260422_r2_postfill/innovus"
set design    "soc_top"
set netlist   "soc_top_postroute_latchfix_r2_postfill.v"
set spef      "soc_top_postroute_latchfix_r2_postfill.spef"
set std_db    "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/NLDM/N16ADFP_StdCelltt0p8v25c.db"
set sram_db   "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/IP/sram/N16ADFP_SRAM/NLDM/N16ADFP_SRAM_tt0p8v0p8v25c_100a.db"
set synlibdir "/eda/synopsys/syn/W-2024.09-SP5-5/libraries/syn"

file mkdir $out_dir

set_app_var search_path [list \
    /home/fy2243/soc_design \
    /home/fy2243/soc_design/rtl \
    $in_dir \
    $synlibdir \
]
set_app_var target_library [list $std_db $sram_db]
set synthetic_library "dw_foundation.sldb"
set_app_var link_library [concat "* " $target_library $synthetic_library]

read_verilog [file join $in_dir $netlist]
current_design $design
link

source /home/fy2243/soc_design/pd/innovus_axi_uartcordic_currentrtl_20260416_r1/with_sram_postdrc.enc.dat/mmmc/modes/mode_func/mode_func.sdc
set_clock_uncertainty -setup 0.100 [get_clocks {clk}]
set_clock_uncertainty -hold  0.000 [get_clocks {clk}]
set_case_analysis 1 [get_ports rst_n]
set clock_reset_ports [get_ports {clk rst_n}]
if {[sizeof_collection $clock_reset_ports] > 0} {
    set_driving_cell -lib_cell INVD1BWP16P90 $clock_reset_ports
}
set in_ports [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]
if {[sizeof_collection $in_ports] > 0} {
    set_driving_cell -lib_cell INVD1BWP16P90 $in_ports
}
set_app_var timing_remove_clock_reconvergence_pessimism true

read_parasitics [file join $in_dir $spef]
update_timing

check_timing > [file join $out_dir check_timing.rpt]
check_timing -verbose > [file join $out_dir check_timing_verbose.rpt]
report_analysis_coverage > [file join $out_dir analysis_coverage.rpt]
report_qor > [file join $out_dir qor.rpt]
report_clock -skew -attribute > [file join $out_dir clock_report.rpt]
report_global_timing > [file join $out_dir global_timing.rpt]
report_constraint -all_violators > [file join $out_dir constraint_violators.rpt]
report_constraint -max_transition -all_violators > [file join $out_dir constraint_max_transition.rpt]
report_constraint -max_capacitance -all_violators > [file join $out_dir constraint_max_capacitance.rpt]
report_timing -delay_type max -max_paths 20 -path_type full_clock_expanded -nets -transition_time -capacitance > [file join $out_dir setup_worst20.rpt]
report_timing -delay_type min -max_paths 50 -path_type full_clock_expanded -nets -transition_time -capacitance > [file join $out_dir hold_worst50.rpt]

proc calc_summary {delay_type} {
    set worst_path [get_timing_paths -delay_type $delay_type -max_paths 1]
    set worst_slack [get_attribute $worst_path slack]
    set violating_paths [get_timing_paths -delay_type $delay_type -max_paths 100000 -slack_lesser_than 0.0]
    set tns 0.0
    set count 0
    foreach_in_collection path $violating_paths {
        set tns [expr {$tns + [get_attribute $path slack]}]
        incr count
    }
    return [list $worst_slack $tns $count]
}

set setup_summary [calc_summary max]
set hold_summary  [calc_summary min]

set fp [open [file join $out_dir summary.txt] w]
puts $fp "PrimeTime functional-mode STA summary"
puts $fp "design=$design"
puts $fp "source_checkpoint=/home/fy2243/soc_design/pd/latchfix_20260422_r2_postfill/postfill_cleaned.enc.dat"
puts $fp "netlist=[file join $in_dir $netlist]"
puts $fp "spef=[file join $in_dir $spef]"
puts $fp "cppr_enabled=true"
puts $fp "rst_n_case_analysis=1"
puts $fp "input_drive_for_clock_reset=INVD1BWP16P90"
puts $fp "input_drive_for_non_clock_non_reset=INVD1BWP16P90"
puts $fp "setup_clock_uncertainty=0.100"
puts $fp "hold_clock_uncertainty=0.000"
puts $fp "setup_wns=[lindex $setup_summary 0]"
puts $fp "setup_tns=[lindex $setup_summary 1]"
puts $fp "setup_violating_paths=[lindex $setup_summary 2]"
puts $fp "hold_wns=[lindex $hold_summary 0]"
puts $fp "hold_tns=[lindex $hold_summary 1]"
puts $fp "hold_violating_paths=[lindex $hold_summary 2]"
close $fp

exit
