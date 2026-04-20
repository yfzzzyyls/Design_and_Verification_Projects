set checkpoint "/home/fy2243/soc_design/pd/holdfix_currentrtl_20260418_r2/with_sram_holdfix_r2.enc.dat"
set design     "soc_top"
set out_root   "/home/fy2243/soc_design/pd/holdfix_currentrtl_20260418_r3"
set sta_root   "/home/fy2243/soc_design/sta/currentrtl_20260418_holdfix_r3/innovus"
set view       "view_typ"

file mkdir $out_root
file mkdir $sta_root
file mkdir [file join $sta_root timeDesign_setup]
file mkdir [file join $sta_root timeDesign_hold]

restoreDesign $checkpoint $design
setMultiCpuUsage -localCpu 8

setExtractRCMode -engine postRoute -effortLevel medium
catch {extractRC}
setAnalysisMode -analysisType onChipVariation -cppr both

setOptMode -fixHoldAllowSetupTnsDegrade false
setOptMode -fixHoldAllowOverlap true
setOptMode -holdTargetSlack 0.250
setOptMode -holdFixingCells {
    DEL025D1BWP16P90 DEL025D1BWP16P90LVT DEL025D1BWP20P90 DEL025D1BWP20P90LVT
    DEL050D1BWP16P90 DEL050D1BWP16P90LVT DEL050D1BWP20P90 DEL050D1BWP20P90LVT
    DEL075D1BWP16P90 DEL075D1BWP16P90LVT DEL075D1BWP20P90 DEL075D1BWP20P90LVT
    BUFFD1BWP16P90 BUFFD1BWP16P90LVT BUFFD1BWP20P90 BUFFD1BWP20P90LVT
    BUFFD2BWP16P90 BUFFD2BWP16P90LVT BUFFD2BWP20P90 BUFFD2BWP20P90LVT
    INVD1BWP16P90 INVD1BWP16P90LVT INVD1BWP20P90 INVD1BWP20P90LVT
}

optDesign -postRoute -hold -expandedViews -outDir $out_root
catch {ecoRoute -fix_drc}
catch {extractRC}

setAnalysisMode -analysisType onChipVariation -cppr both -checkType setup
timeDesign -postRoute -expandedViews -pathreports -slackReports -outDir [file join $sta_root timeDesign_setup]
report_timing -late -max_paths 20 -path_type full -net -view $view > [file join $sta_root setup_worst20.rpt]
report_timing -late -unconstrained -max_paths 20 -path_type full -view $view > [file join $sta_root unconstrained.rpt]

setAnalysisMode -analysisType onChipVariation -cppr both -checkType hold
timeDesign -postRoute -hold -expandedViews -pathreports -slackReports -outDir [file join $sta_root timeDesign_hold]
report_timing -check_type hold -max_paths 20 -path_type full -net -view $view > [file join $sta_root hold_worst20.rpt]

saveDesign [file join $out_root with_sram_holdfix_r3.enc]
saveNetlist [file join $sta_root ${design}_postroute_holdfix_r3.v]
rcOut -spef [file join $sta_root ${design}_postroute_holdfix_r3.spef] -view $view -cUnit pF
write_sdf [file join $sta_root ${design}_postroute_holdfix_r3.sdf] -view $view -recompute_delay_calc -precision 4

set fp [open [file join $sta_root summary.txt] w]
puts $fp "CurrentRTL post-route hold ECO summary"
puts $fp "checkpoint_in=$checkpoint"
puts $fp "checkpoint_out=[file join $out_root with_sram_holdfix_r3.enc]"
puts $fp "setup_summary=[file join $sta_root timeDesign_setup soc_top_postRoute.summary.gz]"
puts $fp "hold_summary=[file join $sta_root timeDesign_hold soc_top_postRoute_hold.summary.gz]"
close $fp

exit
