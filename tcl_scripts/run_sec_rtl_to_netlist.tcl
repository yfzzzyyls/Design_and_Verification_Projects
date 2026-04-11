clear -all

set script_dir [file dirname [file normalize [info script]]]
set pwd_root   [file normalize [pwd]]
set proj_root  ""
if {[file exists [file join $pwd_root mapped_with_tech soc_top.v]]} {
    set proj_root $pwd_root
} else {
    set candidate [file normalize [file join $script_dir ..]]
    if {[file exists [file join $candidate mapped_with_tech soc_top.v]]} {
        set proj_root $candidate
    } else {
        set proj_root $candidate
    }
}
set report_dir [file join $proj_root build formal sec]
file mkdir $report_dir

set top soc_top
set std_v  "/ip/tsmc/tsmc16adfp/stdcell/VERILOG/N16ADFP_StdCell.v"
set sram_v "/ip/tsmc/tsmc16adfp/sram/VERILOG/N16ADFP_SRAM_100a.v"

set spec_rtl [list \
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
set imp_netlist [file join $proj_root mapped_with_tech soc_top.v]

if {![file exists $imp_netlist]} {
    puts "ERROR: Revised netlist not found: $imp_netlist"
    puts "Hint: run synthesis first:"
    puts "  dc_shell -f $proj_root/syn_complete_with_tech.tcl"
    exit 2
}

foreach f $spec_rtl {
    if {![file exists $f]} {
        puts "ERROR: Spec RTL file not found: $f"
        exit 2
    }
}
foreach f [list $std_v $sram_v] {
    if {![file exists $f]} {
        puts "ERROR: Verilog model not found: $f"
        exit 2
    }
}

puts ""
puts "=========================================="
puts "Jasper SEC: RTL vs Netlist"
puts "=========================================="
puts "Top     : $top"
puts "Spec    : RTL (+define+SYNTHESIS)"
puts "Imp     : $imp_netlist"
puts "Reports : $report_dir"
puts ""

set_sec_show_strategy_column on
set_capture_elaborated_design on

check_sec -clear all

# SPEC side (RTL)
check_sec -analyze -spec -sv +define+SYNTHESIS \
    -bbox_m TS1N16ADFPCLLLVTA512X45M4SWSHOD {*}$spec_rtl
check_sec -elaborate -spec -top $top

# IMP side (mapped netlist + cell models)
check_sec -analyze -imp -sv \
    -v $std_v \
    -v $sram_v \
    -bbox_m TS1N16ADFPCLLLVTA512X45M4SWSHOD \
    $imp_netlist
check_sec -elaborate -imp -top $top

check_sec -setup

# Clock/reset intent required before interface/prove.
clock clk
reset ~rst_n

redirect -file [file join $report_dir sec_interface.rpt] -force {check_sec -interface}

# Keep runtime bounded for project-scale regression use.
set_proofgrid_mode local
set_proofgrid_per_engine_max_local_jobs 2
set_proofgrid_max_local_jobs 6
set_prove_time_limit 5m

check_sec -prove

# Save both full and summary signoff reports.
check_sec -signoff \
    -waive_category {x_signals_and_undrivens} \
    -file [file join $report_dir sec_signoff.rpt] \
    -force
set signoff_summary [check_sec -signoff \
    -waive_category {x_signals_and_undrivens} \
    -summary \
    -silent]
redirect -file [file join $report_dir sec_signoff_summary.rpt] -force {
    check_sec -signoff -waive_category {x_signals_and_undrivens} -summary
}

save -elaborated_design [file join $report_dir elaboratedDesign] -force
save -jdb [file join $report_dir sec.jdb] -capture_session_data -no_setup -force

set sec_status "UNKNOWN"
if {[dict exists $signoff_summary {Signoff Summary} {Overall SEC status} Status]} {
    set sec_status [dict get $signoff_summary {Signoff Summary} {Overall SEC status} Status]
}

puts ""
puts "SEC SIGNOFF STATUS: $sec_status"
puts ""

if {[string equal -nocase $sec_status "Complete"]} {
    puts "SEC RESULT: PASS"
    exit 0
}

puts "SEC RESULT: FAIL"
exit 4
