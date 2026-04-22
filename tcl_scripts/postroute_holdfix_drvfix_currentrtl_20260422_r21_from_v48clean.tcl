set checkpoint "/home/fy2243/soc_design/pd/innovus_axi_uartcordic_currentrtl_20260416_r1/with_sram_postdrc.enc.dat"
set design     "soc_top"
set out_root   "/home/fy2243/soc_design/pd/holdfix_drvfix_currentrtl_20260422_r21_from_v48clean"
set sta_root   "/home/fy2243/soc_design/sta/currentrtl_20260422_r21_from_v48clean/innovus"
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

set hold_fixing_cells {
    DEL025D1BWP16P90 DEL025D1BWP16P90LVT DEL025D1BWP20P90 DEL025D1BWP20P90LVT
    DEL050D1BWP16P90 DEL050D1BWP16P90LVT DEL050D1BWP20P90 DEL050D1BWP20P90LVT
    DEL075D1BWP16P90 DEL075D1BWP16P90LVT DEL075D1BWP20P90 DEL075D1BWP20P90LVT
    BUFFD1BWP16P90 BUFFD1BWP16P90LVT BUFFD1BWP20P90 BUFFD1BWP20P90LVT
    BUFFD2BWP16P90 BUFFD2BWP16P90LVT BUFFD2BWP20P90 BUFFD2BWP20P90LVT
    INVD1BWP16P90 INVD1BWP16P90LVT INVD1BWP20P90 INVD1BWP20P90LVT
}

proc safe_run {label cmd} {
    puts "R21_STEP_BEGIN $label"
    set rc [catch {uplevel 1 $cmd} msg]
    puts "R21_STEP_END $label rc=$rc msg=$msg"
    return [list $rc $msg]
}

proc soc_add_fill_region_if_valid {layers llx lly urx ury} {
    if {$urx <= $llx || $ury <= $lly} {
        return
    }
    addMetalFill -layer $layers -timingAware sta -area "$llx $lly $urx $ury"
}

proc soc_add_fill_with_reference_keepouts {llx lly urx ury} {
    set sram_ko_llx 61.80
    set sram_ko_lly 61.70
    set sram_ko_urx 105.35
    set sram_ko_ury 167.90

    set fill_ko_llx 143.45
    set fill_ko_lly 94.35
    set fill_ko_urx 144.15
    set fill_ko_ury 95.45

    soc_add_fill_region_if_valid {M1 M2 M3 M6} $llx $lly $urx $ury

    soc_add_fill_region_if_valid {M5} $llx $lly $urx $fill_ko_lly
    soc_add_fill_region_if_valid {M5} $llx $fill_ko_ury $urx $ury
    soc_add_fill_region_if_valid {M5} $llx $fill_ko_lly $fill_ko_llx $fill_ko_ury
    soc_add_fill_region_if_valid {M5} $fill_ko_urx $fill_ko_lly $urx $fill_ko_ury

    soc_add_fill_region_if_valid {M4} $llx $lly $urx $sram_ko_lly
    soc_add_fill_region_if_valid {M4} $llx $sram_ko_ury $urx $ury
    soc_add_fill_region_if_valid {M4} $llx $sram_ko_lly $sram_ko_llx $sram_ko_ury
    soc_add_fill_region_if_valid {M4} $sram_ko_urx $sram_ko_lly $urx $sram_ko_ury
}

file mkdir $out_root
file mkdir $sta_root
file mkdir [file join $sta_root timeDesign_setup]
file mkdir [file join $sta_root timeDesign_hold_nominal]

restoreDesign $checkpoint $design
setMultiCpuUsage -localCpu 8

setExtractRCMode -engine postRoute -effortLevel medium
setAnalysisMode -analysisType onChipVariation -cppr both
safe_run "extract_rc_initial" {extractRC}

globalNetConnect VDD -type pgpin -pin VDD -all -override
globalNetConnect VDD -type pgpin -pin VDDM -all -override
globalNetConnect VDD -type pgpin -pin VPP -all -override
globalNetConnect VSS -type pgpin -pin VSS -all -override
globalNetConnect VSS -type pgpin -pin VBB -all -override
globalNetConnect VDD -type tiehi -all -override
globalNetConnect VSS -type tielo -all -override

safe_run "delete_existing_metal_fill" {deleteMetalFill}
safe_run "delete_existing_stdcell_fillers" {deleteFiller -prefix FILLER}
safe_run "check_place_after_fill_delete" {checkPlace}

safe_run "set_opt_no_setup_tns_degrade" {setOptMode -fixHoldAllowSetupTnsDegrade false}
safe_run "set_opt_allow_overlap" {setOptMode -fixHoldAllowOverlap true}
safe_run "set_opt_hold_target" {setOptMode -holdTargetSlack 0.300}
safe_run "set_opt_hold_fix_cells" "setOptMode -holdFixingCells {$hold_fixing_cells}"
safe_run "opt_design_postroute_hold" "optDesign -postRoute -hold -expandedViews -outDir [file join $out_root optDesign_hold]"

safe_run "extract_rc_after_hold" {extractRC}
safe_run "set_opt_fix_drc" {setOptMode -fixDrc true}
safe_run "opt_design_postroute_drv" "optDesign -postRoute -drv -expandedViews -outDir [file join $out_root optDesign_drv]"

safe_run "check_place_after_opt" {checkPlace}
safe_run "refine_place_preserve_routes" {refinePlace -preserveRouting true}
safe_run "eco_route_after_opt" {ecoRoute}
for {set i 0} {$i < 8} {incr i} {
    safe_run "eco_route_prefill_fix_drc_$i" {ecoRoute -fix_drc}
}

safe_run "reset_filler_mode" {setFillerMode -reset}
safe_run "set_place_mode_one_site_filler" {setPlaceMode -place_detail_use_no_diffusion_one_site_filler true}
safe_run "set_place_mode_implant" {setPlaceMode -place_detail_no_filler_without_implant true}
safe_run "set_place_mode_diffusion_spacing" {setPlaceMode -place_detail_check_diffusion_forbidden_spacing true}
safe_run "set_filler_mode" "setFillerMode -core {$filler_cells} -preserveUserOrder true -fitGap true -corePrefix FILLER -add_fillers_with_drc false -check_signal_drc true"
safe_run "add_filler" {addFiller}
safe_run "check_filler" {checkFiller}

set bbox [dbGet top.fPlan.box]
set llx [lindex $bbox 0]
set lly [lindex $bbox 1]
set urx [lindex $bbox 2]
set ury [lindex $bbox 3]
safe_run "add_reference_style_metal_fill" "soc_add_fill_with_reference_keepouts $llx $lly $urx $ury"

for {set i 0} {$i < 8} {incr i} {
    set drc_rpt [file join $out_root innovus_verify_drc_after_fix_$i.rpt]
    safe_run "verify_drc_after_fix_$i" "verify_drc -limit 10000 -report $drc_rpt"
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

set checkpoint_out [file join $out_root with_sram_holdfix_drvfix_r21_from_v48clean.enc]
saveDesign $checkpoint_out
saveNetlist [file join $sta_root ${design}_postroute_holdfix_drvfix_r21_from_v48clean.v]
rcOut -spef [file join $sta_root ${design}_postroute_holdfix_drvfix_r21_from_v48clean.spef] -view $view -cUnit pF
write_sdf [file join $sta_root ${design}_postroute_holdfix_drvfix_r21_from_v48clean.sdf] -view $view -recompute_delay_calc -precision 4

set fp [open [file join $sta_root summary.txt] w]
puts $fp "CurrentRTL r21 hold+DRV optimization from Calibre-clean v48 checkpoint"
puts $fp "checkpoint_in=$checkpoint"
puts $fp "checkpoint_out=$checkpoint_out"
puts $fp "final_drc=$final_drc"
puts $fp "final_antenna=$final_antenna"
puts $fp "final_regular_conn=$final_regular"
puts $fp "final_special_conn=$final_special"
puts $fp "setup_summary=[file join $sta_root timeDesign_setup soc_top_postRoute.summary.gz]"
puts $fp "hold_nominal_summary=[file join $sta_root timeDesign_hold_nominal soc_top_postRoute_hold.summary.gz]"
close $fp

exit
