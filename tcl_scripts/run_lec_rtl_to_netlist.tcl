tclmode

set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]
set report_dir [file join $proj_root build formal lec]
file mkdir $report_dir

set top soc_top
set std_lib  "/ip/tsmc/tsmc16adfp/stdcell/NLDM/N16ADFP_StdCelltt0p8v25c.lib"
set sram_lib "/ip/tsmc/tsmc16adfp/sram/NLDM/N16ADFP_SRAM_tt0p8v0p8v25c_100a.lib"

set golden_rtl [list \
    [file join $proj_root rtl soc_top.sv] \
    [file join $proj_root rtl mem_router_native.sv] \
    [file join $proj_root rtl native_periph_bridge.sv] \
    [file join $proj_root rtl axil_interconnect_1x2.sv] \
    [file join $proj_root rtl axil_uart.sv] \
    [file join $proj_root rtl axil_cordic_accel.sv] \
    [file join $proj_root rtl cordic_accel_ctrl.sv] \
    [file join $proj_root rtl sram.sv] \
    [file join $proj_root rtl cordic_core_atan2.sv] \
    [file join $proj_root rtl cordic_core_sincos.sv] \
    [file join $proj_root third_party picorv32 picorv32.v] \
]
set revised_netlist [file join $proj_root mapped_with_tech soc_top.v]

set_log_file [file join $report_dir lec_run.log] -replace
usage -auto -elapse

if {![file exists $revised_netlist]} {
    puts "ERROR: Revised netlist not found: $revised_netlist"
    puts "Hint: run synthesis first:"
    puts "  dc_shell -f $proj_root/syn_complete_with_tech.tcl"
    exit 2
}

foreach f $golden_rtl {
    if {![file exists $f]} {
        puts "ERROR: Golden RTL file not found: $f"
        exit 2
    }
}
foreach f [list $std_lib $sram_lib] {
    if {![file exists $f]} {
        puts "ERROR: Liberty file not found: $f"
        exit 2
    }
}

puts ""
puts "=========================================="
puts "Conformal LEC: RTL vs Netlist"
puts "=========================================="
puts "Top     : $top"
puts "Golden  : RTL (+define+SYNTHESIS)"
puts "Revised : $revised_netlist"
puts "Reports : $report_dir"
puts ""

read_library $std_lib $sram_lib -Liberty -Both -Replace

read_design $golden_rtl -SV -Define SYNTHESIS -Golden -NOELaborate -Replace
elaborate_design -root $top -golden

read_design $revised_netlist -Verilog -NETLIST -Revised -NOELaborate -Replace
elaborate_design -root $top -revised

report_design_data > [file join $report_dir design_data.rpt]
report_black_box -detail > [file join $report_dir black_box.rpt]

set_flatten_model -seq_constant
set_flatten_model -gated_clock
set_parallel_option -threads 8
set_system_mode lec

add_compared_points -all
compare
if {[catch {analyze_abort -compare} abort_msg]} {
    puts "WARN: analyze_abort step skipped ($abort_msg)"
}

report_verification -summary > [file join $report_dir verification_summary.rpt]
report_verification -verbose > [file join $report_dir verification_verbose.rpt]
report_compare_data -noneq > [file join $report_dir compare_noneq.rpt]
report_compare_data -abort > [file join $report_dir compare_abort.rpt]

set diff_list  [get_compare_points -diff]
set abort_list [get_compare_points -abort]
set diff_cnt   [llength $diff_list]
set abort_cnt  [llength $abort_list]

puts ""
puts "LEC compare points:"
puts "  non-equivalent: $diff_cnt"
puts "  abort         : $abort_cnt"
puts ""

if {$diff_cnt > 0 || $abort_cnt > 0} {
    puts "LEC RESULT: FAIL"
    exit 4
}

puts "LEC RESULT: PASS"
exit 0
