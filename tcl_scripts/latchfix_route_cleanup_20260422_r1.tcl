set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]

set checkpoint [expr {[info exists ::env(SOC_ROUTE_ENC)] && $::env(SOC_ROUTE_ENC) ne "" ? [file normalize $::env(SOC_ROUTE_ENC)] : [file join $proj_root pd latchfix_20260422_r1 route.enc.dat]}]
set out_root   [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd latchfix_20260422_r1_cleanup]}]
set design     "soc_top"

file mkdir $out_root

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

proc soc_refresh_pg_connectivity {} {
    globalNetConnect VDD -type pgpin -pin VDD  -all -override
    globalNetConnect VDD -type pgpin -pin VDDM -all -override
    globalNetConnect VDD -type pgpin -pin VPP  -all -override
    globalNetConnect VSS -type pgpin -pin VSS  -all -override
    globalNetConnect VSS -type pgpin -pin VBB  -all -override
    globalNetConnect VDD -type tiehi -all -override
    globalNetConnect VSS -type tielo -all -override
}

restoreDesign $checkpoint $design
setMultiCpuUsage -localCpu 8
soc_refresh_pg_connectivity
setExtractRCMode -engine postRoute -effortLevel medium

set max_iters 5
for {set i 0} {$i <= $max_iters} {incr i} {
    set drc_rpt [file join $out_root innovus_verify_drc_iter${i}.rpt]
    verify_drc -limit 10000 -report $drc_rpt
    set num [parse_drc_violations $drc_rpt]
    puts "LATCHFIX_CLEANUP_DRC_ITER $i violations=$num report=$drc_rpt"
    if {$num == 0} {
        break
    }
    if {$i < $max_iters} {
        catch {ecoRoute -fix_drc} eco_msg
        puts "LATCHFIX_CLEANUP_ECOROUTE_ITER $i msg=$eco_msg"
    }
}

set final_drc [file join $out_root innovus_verify_drc_final.rpt]
set final_regular [file join $out_root innovus_conn_regular_final.rpt]
set final_special [file join $out_root innovus_conn_special_final.rpt]
set final_antenna [file join $out_root innovus_antenna_final.rpt]

verify_drc -limit 10000 -report $final_drc
verifyConnectivity -type regular -error 1000 -warning 100 -report $final_regular
verifyConnectivity -type special -noAntenna -error 2000 -warning 100 -report $final_special
catch {verifyProcessAntenna -report $final_antenna} antenna_msg

set checkpoint_out [file join $out_root route_cleaned.enc]
saveDesign $checkpoint_out

puts "LATCHFIX_CLEANUP_SUMMARY checkpoint_in=$checkpoint"
puts "LATCHFIX_CLEANUP_SUMMARY checkpoint_out=$checkpoint_out"
puts "LATCHFIX_CLEANUP_SUMMARY final_drc=$final_drc"
puts "LATCHFIX_CLEANUP_SUMMARY final_regular=$final_regular"
puts "LATCHFIX_CLEANUP_SUMMARY final_special=$final_special"
puts "LATCHFIX_CLEANUP_SUMMARY final_antenna=$final_antenna"
exit
