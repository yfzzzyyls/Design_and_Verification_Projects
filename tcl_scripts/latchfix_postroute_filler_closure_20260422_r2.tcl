set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]

set checkpoint [expr {[info exists ::env(SOC_ROUTE_ENC)] && $::env(SOC_ROUTE_ENC) ne "" ? [file normalize $::env(SOC_ROUTE_ENC)] : [file join $proj_root pd latchfix_20260422_r1_cleanup route_cleaned.enc.dat]}]
set out_root   [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd latchfix_20260422_r2_postfill]}]
set sta_root   [expr {[info exists ::env(SOC_STA_OUT_DIR)] && $::env(SOC_STA_OUT_DIR) ne "" ? [file normalize $::env(SOC_STA_OUT_DIR)] : [file join $proj_root sta currentrtl_latchfix_20260422_r2_postfill innovus]}]
set design     "soc_top"
set view       "view_typ"

set filler_cells {
    DCAP64BWP20P90 DCAP64BWP16P90 DCAP64BWP20P90LVT DCAP64BWP16P90LVT
    DCAP32BWP20P90 DCAP32BWP16P90 DCAP32BWP20P90LVT DCAP32BWP16P90LVT
    DCAP16BWP20P90 DCAP16BWP16P90 DCAP16BWP20P90LVT DCAP16BWP16P90LVT
    DCAP8BWP20P90 DCAP8BWP16P90 DCAP8BWP20P90LVT DCAP8BWP16P90LVT
    DCAP4BWP20P90 DCAP4BWP16P90 DCAP4BWP20P90LVT DCAP4BWP16P90LVT
    FILL64BWP20P90 FILL64BWP16P90 FILL64BWP20P90LVT FILL64BWP16P90LVT
    FILL32BWP20P90 FILL32BWP16P90 FILL32BWP20P90LVT FILL32BWP16P90LVT
    FILL16BWP20P90 FILL16BWP16P90 FILL16BWP20P90LVT FILL16BWP16P90LVT
    FILL8BWP20P90 FILL8BWP16P90 FILL8BWP20P90LVT FILL8BWP16P90LVT
    FILL4BWP20P90 FILL4BWP16P90 FILL4BWP20P90LVT FILL4BWP16P90LVT
    FILL3BWP20P90 FILL3BWP16P90 FILL3BWP20P90LVT FILL3BWP16P90LVT
    FILL2BWP20P90 FILL2BWP16P90 FILL2BWP20P90LVT FILL2BWP16P90LVT
    FILL1BWP20P90 FILL1BWP16P90 FILL1BWP20P90LVT FILL1BWP16P90LVT
}

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

proc safe_run {label cmd} {
    puts "LATCHFIX_R2_STEP_BEGIN $label"
    set rc [catch {uplevel 1 $cmd} msg]
    puts "LATCHFIX_R2_STEP_END $label rc=$rc msg=$msg"
    return [list $rc $msg]
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

file mkdir $out_root
file mkdir $sta_root
file mkdir [file join $sta_root timeDesign_setup]
file mkdir [file join $sta_root timeDesign_hold_nominal]

restoreDesign $checkpoint $design
setMultiCpuUsage -localCpu 8
soc_refresh_pg_connectivity

setExtractRCMode -engine postRoute -effortLevel medium
setAnalysisMode -analysisType onChipVariation -cppr both

# Match the r23 signoff style: keep stdcell fillers, but do not keep Innovus metal fill.
safe_run "delete_existing_metal_fill" {deleteMetalFill}
safe_run "delete_existing_stdcell_fillers" {deleteFiller -prefix FILLER}

safe_run "reset_filler_mode" {setFillerMode -reset}
safe_run "set_place_mode_one_site_filler" {setPlaceMode -place_detail_use_no_diffusion_one_site_filler true}
safe_run "set_place_mode_implant" {setPlaceMode -place_detail_no_filler_without_implant true}
safe_run "set_place_mode_diffusion_spacing" {setPlaceMode -place_detail_check_diffusion_forbidden_spacing true}
safe_run "set_filler_mode" "setFillerMode -core {$filler_cells} -preserveUserOrder true -fitGap true -corePrefix FILLER -add_fillers_with_drc false -check_signal_drc true"
safe_run "add_filler" {addFiller}
safe_run "check_filler_after_add" {checkFiller}
safe_run "check_place_after_add" {checkPlace}

set max_iters 6
for {set i 0} {$i <= $max_iters} {incr i} {
    set drc_rpt [file join $out_root innovus_verify_drc_postfill_iter${i}.rpt]
    safe_run "verify_drc_postfill_iter${i}" "verify_drc -limit 10000 -report $drc_rpt"
    set num [parse_drc_violations $drc_rpt]
    puts "LATCHFIX_R2_DRC_ITER $i violations=$num report=$drc_rpt"
    if {$num == 0} {
        break
    }
    if {$i < $max_iters} {
        safe_run "eco_route_postfill_fix_drc_${i}" {ecoRoute -fix_drc}
    }
}

set final_drc [file join $out_root innovus_verify_drc_final.rpt]
set final_regular [file join $out_root innovus_conn_regular_final.rpt]
set final_special [file join $out_root innovus_conn_special_final.rpt]
set final_antenna [file join $out_root innovus_antenna_final.rpt]

safe_run "verify_drc_final" "verify_drc -limit 10000 -report $final_drc"
safe_run "verify_connectivity_regular_final" "verifyConnectivity -type regular -error 1000 -warning 100 -report $final_regular"
safe_run "verify_connectivity_special_final" "verifyConnectivity -type special -noAntenna -error 2000 -warning 100 -report $final_special"
safe_run "verify_antenna_final" "verifyProcessAntenna -report $final_antenna"
set check_place_final [safe_run "check_place_final" {checkPlace}]
set check_filler_final [safe_run "check_filler_final" {checkFiller}]

safe_run "extract_rc_final" {extractRC}

setAnalysisMode -analysisType onChipVariation -cppr both -checkType setup
timeDesign -postRoute -expandedViews -pathreports -slackReports -outDir [file join $sta_root timeDesign_setup]
report_timing -late -max_paths 20 -path_type full -net -view $view > [file join $sta_root setup_worst20.rpt]
report_timing -late -unconstrained -max_paths 20 -path_type full -view $view > [file join $sta_root unconstrained.rpt]

setAnalysisMode -analysisType onChipVariation -cppr both -checkType hold
timeDesign -postRoute -hold -expandedViews -pathreports -slackReports -outDir [file join $sta_root timeDesign_hold_nominal]
report_timing -check_type hold -max_paths 50 -path_type full -net -view $view > [file join $sta_root hold_nominal_worst50.rpt]

set checkpoint_out [file join $out_root postfill_cleaned.enc]
saveDesign $checkpoint_out
saveNetlist [file join $sta_root ${design}_postroute_latchfix_r2_postfill.v]
rcOut -spef [file join $sta_root ${design}_postroute_latchfix_r2_postfill.spef] -view $view -cUnit pF
write_sdf [file join $sta_root ${design}_postroute_latchfix_r2_postfill.sdf] -view $view -recompute_delay_calc -precision 4

set fp [open [file join $sta_root summary.txt] w]
puts $fp "CurrentRTL latch-fix r2 post-route filler closure"
puts $fp "checkpoint_in=$checkpoint"
puts $fp "checkpoint_out=$checkpoint_out"
puts $fp "check_place_final=$check_place_final"
puts $fp "check_filler_final=$check_filler_final"
puts $fp "final_drc=$final_drc"
puts $fp "final_antenna=$final_antenna"
puts $fp "final_regular_conn=$final_regular"
puts $fp "final_special_conn=$final_special"
puts $fp "setup_summary=[file join $sta_root timeDesign_setup soc_top_postRoute.summary.gz]"
puts $fp "hold_nominal_summary=[file join $sta_root timeDesign_hold_nominal soc_top_postRoute_hold.summary.gz]"
close $fp

puts "LATCHFIX_R2_SUMMARY checkpoint_in=$checkpoint"
puts "LATCHFIX_R2_SUMMARY checkpoint_out=$checkpoint_out"
puts "LATCHFIX_R2_SUMMARY sta_root=$sta_root"
puts "LATCHFIX_R2_SUMMARY final_drc=$final_drc"
puts "LATCHFIX_R2_SUMMARY final_regular=$final_regular"
puts "LATCHFIX_R2_SUMMARY final_special=$final_special"
puts "LATCHFIX_R2_SUMMARY final_antenna=$final_antenna"

exit
