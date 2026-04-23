set checkpoint "/home/fy2243/soc_design/pd/latchfix_20260422_r4_sram_hold/postfill_sram_hold_r4.enc.dat"
set design     "soc_top"
set out_root   "/home/fy2243/soc_design/pd/latchfix_20260422_r5_web_hold"
set sta_root   "/home/fy2243/soc_design/sta/currentrtl_latchfix_20260422_r5_web_hold/innovus"
set view       "view_typ"
set delay_cell "DEL075D1BWP20P90"

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

proc safe_run {label cmd} {
    puts "R5_STEP_BEGIN $label"
    set rc [catch {uplevel 1 $cmd} msg]
    puts "R5_STEP_END $label rc=$rc msg=$msg"
    return [list $rc $msg]
}

proc append_bus_terms {terms_var prefix first last} {
    upvar $terms_var terms
    for {set i $first} {$i <= $last} {incr i} {
        lappend terms [format {%s[%d]} $prefix $i]
    }
}

file mkdir $out_root
file mkdir $sta_root
file mkdir [file join $sta_root timeDesign_setup]
file mkdir [file join $sta_root timeDesign_hold_nominal]

restoreDesign $checkpoint $design
setMultiCpuUsage -localCpu 8

setExtractRCMode -engine postRoute -effortLevel medium
setAnalysisMode -analysisType onChipVariation -cppr both

globalNetConnect VDD -type pgpin -pin VDD -all -override
globalNetConnect VDD -type pgpin -pin VDDM -all -override
globalNetConnect VDD -type pgpin -pin VPP -all -override
globalNetConnect VSS -type pgpin -pin VSS -all -override
globalNetConnect VSS -type pgpin -pin VBB -all -override
globalNetConnect VDD -type tiehi -all -override
globalNetConnect VSS -type tielo -all -override

safe_run "extract_rc_initial" {extractRC}
safe_run "delete_existing_fillers_for_eco" {deleteFiller -prefix FILLER}

set hold_terms {u_sram/u_sram_macro/WEB}

set inserted 0
set failed {}
set index 0
foreach term $hold_terms {
    set inst_name [format "PT_HOLD_R5_%03d" $index]
    set net_name  [format "PT_HOLD_R5_%03d_net" $index]
    set rc [catch {
        ecoAddRepeater -term $term -cell $delay_cell -name $inst_name -newNetName $net_name
    } msg]
    puts "R5_HOLD_ECO index=$index term=$term inst=$inst_name cell=$delay_cell rc=$rc msg=$msg"
    if {$rc == 0} {
        incr inserted
    } else {
        lappend failed [list $term $msg]
    }
    incr index
}

safe_run "refine_place_after_hold_eco" {refinePlace -preserveRouting true}
safe_run "eco_route_hold_eco" {ecoRoute}
for {set i 0} {$i < 8} {incr i} {
    safe_run "eco_route_fix_drc_$i" {ecoRoute -fix_drc}
}

safe_run "set_place_mode_one_site_filler" {setPlaceMode -place_detail_use_no_diffusion_one_site_filler true}
safe_run "set_place_mode_implant" {setPlaceMode -place_detail_no_filler_without_implant true}
safe_run "set_place_mode_diffusion_spacing" {setPlaceMode -place_detail_check_diffusion_forbidden_spacing true}
safe_run "set_filler_mode" "setFillerMode -core {$filler_cells} -preserveUserOrder true -fitGap true -corePrefix FILLER -add_fillers_with_drc false -check_signal_drc true"
safe_run "add_filler_after_hold_eco" {addFiller}
safe_run "check_filler_after_hold_eco" {checkFiller}

for {set i 0} {$i < 8} {incr i} {
    set drc_rpt [file join $out_root innovus_verify_drc_after_hold_$i.rpt]
    safe_run "verify_drc_after_hold_$i" "verify_drc -limit 10000 -report $drc_rpt"
    safe_run "eco_route_postfill_fix_drc_$i" {ecoRoute -fix_drc}
}

set final_drc [file join $out_root innovus_verify_drc_final.rpt]
set final_antenna [file join $out_root innovus_antenna_final.rpt]
set final_regular [file join $out_root innovus_conn_regular_final.rpt]
set final_special [file join $out_root innovus_conn_special_final.rpt]
safe_run "verify_drc_final" "verify_drc -limit 10000 -report $final_drc"
safe_run "verify_antenna_final" "verifyProcessAntenna -report $final_antenna"
safe_run "verify_connectivity_regular_final" "verifyConnectivity -type regular -report $final_regular"
safe_run "verify_connectivity_special_final" "verifyConnectivity -type special -report $final_special"
safe_run "check_place_final" {checkPlace}
safe_run "check_filler_final" {checkFiller}
safe_run "extract_rc_final" {extractRC}

setAnalysisMode -analysisType onChipVariation -cppr both -checkType setup
timeDesign -postRoute -expandedViews -pathreports -slackReports -outDir [file join $sta_root timeDesign_setup]
report_timing -late -max_paths 20 -path_type full -net -view $view > [file join $sta_root setup_worst20.rpt]
report_timing -late -unconstrained -max_paths 20 -path_type full -view $view > [file join $sta_root unconstrained.rpt]

setAnalysisMode -analysisType onChipVariation -cppr both -checkType hold
timeDesign -postRoute -hold -expandedViews -pathreports -slackReports -outDir [file join $sta_root timeDesign_hold_nominal]
report_timing -check_type hold -max_paths 50 -path_type full -net -view $view > [file join $sta_root hold_nominal_worst50.rpt]

set checkpoint_out [file join $out_root postfill_web_hold_r5.enc]
saveDesign $checkpoint_out
saveNetlist [file join $sta_root ${design}_postroute_latchfix_r5_web_hold.v]
rcOut -spef [file join $sta_root ${design}_postroute_latchfix_r5_web_hold.spef] -view $view -cUnit pF
write_sdf [file join $sta_root ${design}_postroute_latchfix_r5_web_hold.sdf] -view $view -recompute_delay_calc -precision 4

set fp [open [file join $sta_root summary.txt] w]
puts $fp "Latchfix r5 WEB targeted hold ECO summary"
puts $fp "checkpoint_in=$checkpoint"
puts $fp "checkpoint_out=$checkpoint_out"
puts $fp "delay_cell=$delay_cell"
puts $fp "target_terms=[llength $hold_terms]"
puts $fp "inserted=$inserted"
puts $fp "failed=$failed"
puts $fp "final_drc=$final_drc"
puts $fp "final_antenna=$final_antenna"
puts $fp "final_regular_conn=$final_regular"
puts $fp "final_special_conn=$final_special"
puts $fp "setup_summary=[file join $sta_root timeDesign_setup soc_top_postRoute.summary.gz]"
puts $fp "hold_nominal_summary=[file join $sta_root timeDesign_hold_nominal soc_top_postRoute_hold.summary.gz]"
close $fp

exit
