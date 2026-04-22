set checkpoint "/home/fy2243/soc_design/pd/drvfix_currentrtl_20260422_r22_targeted_from_r21/with_sram_drvfix_r22_targeted_from_r21.enc.dat"
set design     "soc_top"
set out_root   "/home/fy2243/soc_design/pd/nofill_currentrtl_20260422_r23_from_r22"
set sta_root   "/home/fy2243/soc_design/sta/currentrtl_20260422_r23_nofill_from_r22/innovus"
set view       "view_typ"

proc safe_run {label cmd} {
    puts "R23_STEP_BEGIN $label"
    set rc [catch {uplevel 1 $cmd} msg]
    puts "R23_STEP_END $label rc=$rc msg=$msg"
    return [list $rc $msg]
}

file mkdir $out_root
file mkdir $sta_root
file mkdir [file join $sta_root timeDesign_setup]
file mkdir [file join $sta_root timeDesign_hold_nominal]

restoreDesign $checkpoint $design
setMultiCpuUsage -localCpu 8

globalNetConnect VDD -type pgpin -pin VDD -all -override
globalNetConnect VDD -type pgpin -pin VDDM -all -override
globalNetConnect VDD -type pgpin -pin VPP -all -override
globalNetConnect VSS -type pgpin -pin VSS -all -override
globalNetConnect VSS -type pgpin -pin VBB -all -override
globalNetConnect VDD -type tiehi -all -override
globalNetConnect VSS -type tielo -all -override

setExtractRCMode -engine postRoute -effortLevel medium
setAnalysisMode -analysisType onChipVariation -cppr both

safe_run "delete_innovus_metal_fill" {deleteMetalFill}
safe_run "check_place_after_metal_fill_delete" {checkPlace}
safe_run "check_filler_after_metal_fill_delete" {checkFiller}

for {set i 0} {$i < 4} {incr i} {
    set drc_rpt [file join $out_root innovus_verify_drc_after_nofill_$i.rpt]
    safe_run "verify_drc_after_nofill_$i" "verify_drc -limit 10000 -report $drc_rpt"
    safe_run "eco_route_after_nofill_fix_drc_$i" {ecoRoute -fix_drc}
}

set final_drc [file join $out_root innovus_verify_drc_final.rpt]
set final_antenna [file join $out_root innovus_antenna_final.rpt]
set final_regular [file join $out_root innovus_conn_regular_final.rpt]
set final_special [file join $out_root innovus_conn_special_final.rpt]
safe_run "verify_drc_final" "verify_drc -limit 10000 -report $final_drc"
safe_run "verify_antenna_final" "verifyProcessAntenna -report $final_antenna"
safe_run "verify_connectivity_regular_final" "verifyConnectivity -type regular -report $final_regular"
safe_run "verify_connectivity_special_final" "verifyConnectivity -type special -report $final_special"
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

set checkpoint_out [file join $out_root with_sram_drvfix_r23_nofill_from_r22.enc]
saveDesign $checkpoint_out
saveNetlist [file join $sta_root ${design}_postroute_drvfix_r23_nofill_from_r22.v]
rcOut -spef [file join $sta_root ${design}_postroute_drvfix_r23_nofill_from_r22.spef] -view $view -cUnit pF
write_sdf [file join $sta_root ${design}_postroute_drvfix_r23_nofill_from_r22.sdf] -view $view -recompute_delay_calc -precision 4

set fp [open [file join $sta_root summary.txt] w]
puts $fp "CurrentRTL r23 no-Innovus-metal-fill checkpoint from timing-clean r22"
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

exit
