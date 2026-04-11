set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]

set base_final_enc [expr {[info exists ::env(SOC_BASE_FINAL_ENC)] && $::env(SOC_BASE_FINAL_ENC) ne "" ? [file normalize $::env(SOC_BASE_FINAL_ENC)] : [file join $proj_root pd innovus_16boundary_nolvt_tapswap_20260410 with_sram_final.enc.dat]}]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd innovus_edgefill_20260410]}]
set swap_list [expr {[info exists ::env(SOC_SWAP_LIST)] && $::env(SOC_SWAP_LIST) ne "" ? [file normalize $::env(SOC_SWAP_LIST)] : [file join $pnr_out_dir edge_swap_targets.tsv]}]
file mkdir $pnr_out_dir

proc read_text_file {path} {
    set fp [open $path r]
    set data [read $fp]
    close $fp
    return $data
}

proc parse_drc_violations {rpt} {
    if {![file exists $rpt]} { return -1 }
    set content [read_text_file $rpt]
    if {[regexp -nocase {No\s+DRC\s+violations\s+were\s+found} $content]} { return 0 }
    if {[regexp -nocase {No\s+violations\s+were\s+found} $content]} { return 0 }
    if {[regexp {Total\s+Violations\s*:\s*([0-9]+)} $content -> num]} { return $num }
    return -1
}

proc parse_connectivity_errors {rpt} {
    if {![file exists $rpt]} { return -1 }
    set content [read_text_file $rpt]
    if {[regexp -nocase {Found\s+no\s+problems\s+or\s+warnings\.} $content]} { return 0 }
    set total 0
    foreach line [split $content "\n"] {
        if {[regexp {^\s*([0-9]+)\s+Problem\(s\)} $line -> num]} {
            incr total $num
        }
    }
    if {$total > 0} { return $total }
    if {[regexp -nocase {Total\s+(Regular|Special)\s+Net\s+Errors\s*:\s*([0-9]+)} $content -> _ num]} { return $num }
    return -1
}

proc soc_refresh_pg_connectivity {} {
    globalNetConnect VDD -type pgpin -pin VDD -all -override
    globalNetConnect VDD -type pgpin -pin VDDM -all -override
    globalNetConnect VDD -type pgpin -pin VPP -all -override
    globalNetConnect VSS -type pgpin -pin VSS -all -override
    globalNetConnect VSS -type pgpin -pin VBB -all -override
    globalNetConnect VDD -type tiehi -all -override
    globalNetConnect VSS -type tielo -all -override
}

if {![file exists $swap_list]} {
    puts "ERROR: swap list not found: $swap_list"
    exit 2
}

restoreDesign $base_final_enc soc_top
soc_refresh_pg_connectivity

set changed 0
set failed 0
set skipped 0

setEcoMode -batchMode true
set fp [open $swap_list r]
while {[gets $fp line] >= 0} {
    set line [string trim $line]
    if {$line eq "" || [string match "#*" $line]} { continue }
    lassign $line inst old_cell new_cell
    if {$inst eq "" || $new_cell eq ""} {
        incr skipped
        continue
    }
    set rc [catch {ecoChangeCell -inst $inst -cell $new_cell} out]
    if {$rc != 0} {
        puts "SWAP_FAIL $inst $old_cell $new_cell :: $out"
        incr failed
    } else {
        incr changed
    }
}
close $fp
setEcoMode -batchMode false

soc_refresh_pg_connectivity
catch {checkPlace}

set drc_rpt [file join $pnr_out_dir edgefill_native_drc.rpt]
set reg_rpt [file join $pnr_out_dir edgefill_regular.rpt]
set spc_rpt [file join $pnr_out_dir edgefill_special.rpt]
verify_drc -limit 10000 -report $drc_rpt
verifyConnectivity -type regular -error 1000 -warning 100 -report $reg_rpt
verifyConnectivity -type special -noAntenna -error 1000 -warning 100 -report $spc_rpt

saveDesign [file join $pnr_out_dir with_sram_final.enc]

puts "EDGE_SWAP_SUMMARY changed=$changed failed=$failed skipped=$skipped DRC=[parse_drc_violations $drc_rpt] REG=[parse_connectivity_errors $reg_rpt] SPC=[parse_connectivity_errors $spc_rpt]"
exit
