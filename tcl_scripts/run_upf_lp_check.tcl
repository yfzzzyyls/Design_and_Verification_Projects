# UPF low-power check driver for soc_top using Synopsys VC Static.
#
# Usage example:
#   /eda/synopsys/vc_static/U-2023.03-SP2-5/bin/vc_static_shell \
#     -batch \
#     -session /home/fy2243/soc_design/build/upf_lp/vc_session \
#     -f /home/fy2243/soc_design/tcl_scripts/run_upf_lp_check.tcl
#
# Optional overrides:
#   setenv UPF_NETLIST /path/to/soc_top.v
#   setenv UPF_FILE    /path/to/soc_top.upf

proc resolve_path {default_path env_name} {
    if {[info exists ::env($env_name)] && $::env($env_name) ne ""} {
        return [file normalize $::env($env_name)]
    }
    return [file normalize $default_path]
}

proc extract_counts {msg} {
    if {[regexp {MESSAGE_SUMMARY:\s*([0-9]+)\s+error,\s*([0-9]+)\s+warning,\s*and\s*([0-9]+)\s+info} $msg -> e w i]} {
        return [list $e $w $i]
    }
    return [list -1 -1 -1]
}

set script_dir [file dirname [file normalize [info script]]]
set proj_root [file normalize [file join $script_dir ..]]
set report_dir [file join $proj_root build upf_lp reports]
file mkdir $report_dir

set netlist_default [file join $proj_root mapped_with_tech soc_top.v]
set upf_default [file join $proj_root soc_top.upf]
set netlist [resolve_path $netlist_default UPF_NETLIST]
set upf_file [resolve_path $upf_default UPF_FILE]

if {![file exists $netlist]} {
    puts "ERROR: Netlist not found: $netlist"
    puts "Hint: run synthesis first, e.g."
    puts "  /eda/synopsys/syn/W-2024.09-SP5-5/bin/dc_shell -f $proj_root/syn_complete_with_tech.tcl"
    exit 2
}

if {![file exists $upf_file]} {
    puts "ERROR: UPF file not found: $upf_file"
    exit 2
}

puts ""
puts "=========================================="
puts "VC Static UPF/LP Check"
puts "=========================================="
puts "Netlist : $netlist"
puts "UPF     : $upf_file"
puts "Reports : $report_dir"
puts ""

set sh_continue_on_error true

read_file -netlist -format verilog -top soc_top $netlist
read_upf $upf_file

redirect -variable upf_msg {check_lp -stage upf}
redirect -variable des_msg {check_lp -stage design}
redirect -variable pg_msg  {check_lp -stage pg}
redirect -variable lic_msg {list_licenses}

set upf_counts [extract_counts $upf_msg]
set des_counts [extract_counts $des_msg]
set pg_counts  [extract_counts $pg_msg]

set summary_file [file join $report_dir lp_stage_summary.txt]
set upf_file_log [file join $report_dir lp_stage_upf.log]
set des_file_log [file join $report_dir lp_stage_design.log]
set pg_file_log  [file join $report_dir lp_stage_pg.log]
set lic_file_log [file join $report_dir lp_licenses.log]

set fp [open $summary_file w]
puts $fp "UPF LP Stage Summary"
puts $fp "Generated: [clock format [clock seconds]]"
puts $fp "Netlist: $netlist"
puts $fp "UPF: $upf_file"
puts $fp ""
puts $fp "Stage,Errors,Warnings,Infos"
puts $fp "upf,[lindex $upf_counts 0],[lindex $upf_counts 1],[lindex $upf_counts 2]"
puts $fp "design,[lindex $des_counts 0],[lindex $des_counts 1],[lindex $des_counts 2]"
puts $fp "pg,[lindex $pg_counts 0],[lindex $pg_counts 1],[lindex $pg_counts 2]"
close $fp

set fp [open $upf_file_log w]
puts $fp $upf_msg
close $fp

set fp [open $des_file_log w]
puts $fp $des_msg
close $fp

set fp [open $pg_file_log w]
puts $fp $pg_msg
close $fp

set fp [open $lic_file_log w]
puts $fp $lic_msg
close $fp

puts "Stage summary written: $summary_file"
puts "UPF stage log        : $upf_file_log"
puts "Design stage log     : $des_file_log"
puts "PG stage log         : $pg_file_log"
puts "License log          : $lic_file_log"
puts ""
puts "UPF stage counts     : $upf_counts"
puts "Design stage counts  : $des_counts"
puts "PG stage counts      : $pg_counts"
puts ""

exit
