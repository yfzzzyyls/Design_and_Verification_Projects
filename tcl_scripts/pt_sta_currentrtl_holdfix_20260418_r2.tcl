set out_dir   "/home/fy2243/soc_design/sta/currentrtl_20260418_holdfix_r2/primetime"
set in_dir    "/home/fy2243/soc_design/sta/currentrtl_20260418_holdfix_r2/innovus"
set design    "soc_top"
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

read_verilog [file join $in_dir ${design}_postroute_holdfix_r2.v]
current_design $design
link

source /home/fy2243/soc_design/pd/innovus_axi_uartcordic_currentrtl_20260416_r1/with_sram_postdrc.enc.dat/mmmc/modes/mode_func/mode_func.sdc
set_app_var timing_remove_clock_reconvergence_pessimism true

read_parasitics [file join $in_dir ${design}_postroute_holdfix_r2.spef]
update_timing

check_timing > [file join $out_dir check_timing.rpt]
report_qor > [file join $out_dir qor.rpt]
report_global_timing > [file join $out_dir global_timing.rpt]
report_constraint -all_violators > [file join $out_dir constraint_violators.rpt]
report_timing -delay_type max -max_paths 20 -path_type full_clock_expanded -nets -transition_time -capacitance > [file join $out_dir setup_worst20.rpt]
report_timing -delay_type min -max_paths 20 -path_type full_clock_expanded -nets -transition_time -capacitance > [file join $out_dir hold_worst20.rpt]

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
puts $fp "PrimeTime STA summary"
puts $fp "design=$design"
puts $fp "cppr_enabled=true"
puts $fp "setup_wns=[lindex $setup_summary 0]"
puts $fp "setup_tns=[lindex $setup_summary 1]"
puts $fp "setup_violating_paths=[lindex $setup_summary 2]"
puts $fp "hold_wns=[lindex $hold_summary 0]"
puts $fp "hold_tns=[lindex $hold_summary 1]"
puts $fp "hold_violating_paths=[lindex $hold_summary 2]"
close $fp

exit
