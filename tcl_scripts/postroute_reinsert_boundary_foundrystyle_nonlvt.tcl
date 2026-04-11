set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]

set base_enc [expr {[info exists ::env(SOC_BASE_ENC)] && $::env(SOC_BASE_ENC) ne "" ? [file normalize $::env(SOC_BASE_ENC)] : [file join $proj_root pd innovus_16boundary_lightfinal_20260410 with_sram_final.enc.dat]}]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd innovus_boundaryrefit_nonlvt_20260410]}]
set core_boundary_only [expr {[info exists ::env(SOC_CORE_BOUNDARY_ONLY)] && $::env(SOC_CORE_BOUNDARY_ONLY) ne "" && $::env(SOC_CORE_BOUNDARY_ONLY) ne "0"}]
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
    if {[regexp {([0-9]+)\s+Problem\(s\)} $content -> num]} { return $num }
    if {[regexp -nocase {Total\s+(Regular|Special)\s+Net\s+Errors\s*:\s*([0-9]+)} $content -> _ num]} { return $num }
    return -1
}

proc parse_antenna_violations {rpt} {
    if {![file exists $rpt]} { return -1 }
    set content [read_text_file $rpt]
    if {[regexp -nocase {No\s+Violations\s+Found} $content]} { return 0 }
    if {[regexp -nocase {Verification\s+Complete\s*:\s*([0-9]+)\s+Violations} $content -> num]} { return $num }
    if {[regexp -nocase {Total\s+number\s+of\s+process\s+antenna\s+violations\s*=\s*([0-9]+)} $content -> num]} { return $num }
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

proc soc_delete_perimeter_cells {} {
    foreach pattern {EC* WELLTAP*} {
        set insts [dbGet top.insts.name $pattern -e]
        if {[llength $insts] > 0} {
            deleteInst $insts
        }
    }
}

proc soc_insert_foundrystyle_perimeter {} {
    set core_boundary_only $::core_boundary_only
    set use_boundary_tap [expr {!$core_boundary_only}]
    setEndCapMode -reset
    setEndCapMode \
        -prefix EC \
        -rightEdge {BOUNDARY_LEFTBWP20P90} \
        -leftEdge {BOUNDARY_RIGHTBWP20P90} \
        -leftTopCorner {BOUNDARY_PCORNERBWP20P90} \
        -leftBottomCorner {BOUNDARY_NCORNERBWP20P90} \
        -topEdge {BOUNDARY_PROW1BWP20P90 BOUNDARY_PROW2BWP20P90 BOUNDARY_PROW3BWP20P90 BOUNDARY_PROW4BWP20P90} \
        -bottomEdge {BOUNDARY_NROW1BWP20P90 BOUNDARY_NROW2BWP20P90 BOUNDARY_NROW3BWP20P90 BOUNDARY_NROW4BWP20P90} \
        -leftTopEdge {FILL3BWP20P90} \
        -leftBottomEdge {FILL3BWP20P90} \
        -rightTopEdge {FILL3BWP20P90} \
        -rightBottomEdge {FILL3BWP20P90} \
        -fitGap true \
        -boundary_tap $use_boundary_tap
    set_well_tap_mode \
        -rule 50.76 \
        -bottom_tap_cell {BOUNDARY_NTAPBWP20P90_VPP_VSS} \
        -top_tap_cell {BOUNDARY_PTAPBWP20P90_VPP_VSS} \
        -cell {TAPCELLBWP20P90_VPP_VSS}
    if {$core_boundary_only} {
        set core_box [join [dbGet top.fPlan.coreBox]]
        set core_llx [lindex $core_box 0]
        set core_lly [lindex $core_box 1]
        set core_urx [lindex $core_box 2]
        set core_ury [lindex $core_box 3]
        set strip_w 2.0
        set strip_h 2.0
        set area_boxes [list \
            [list $core_llx $core_lly $core_urx [expr {$core_lly + $strip_h}]] \
            [list $core_llx [expr {$core_ury - $strip_h}] $core_urx $core_ury] \
            [list $core_llx [expr {$core_lly + $strip_h}] [expr {$core_llx + $strip_w}] [expr {$core_ury - $strip_h}]] \
            [list [expr {$core_urx - $strip_w}] [expr {$core_lly + $strip_h}] $core_urx [expr {$core_ury - $strip_h}]]]
        foreach box $area_boxes {
            addEndCap -area $box
        }
    } else {
        addEndCap
    }

    set_well_tap_mode -reset
    set_well_tap_mode -insert_cells {{TAPCELLBWP20P90_VPP_VSS rule 50.76}}
    addWellTap -checkerBoard
}

proc soc_repair_pg_routes {} {
    setNanoRouteMode -routeAllowPowerGroundPin true
    catch {setAttribute -net VDD -skip_routing false}
    catch {setPGPinUseSignalRoute TAPCELL*:VPP BOUNDARY_*TAP*:VPP}
    catch {
        sroute -nets {VDD VSS} -connect {corePin} \
            -corePinTarget {ring stripe} \
            -layerChangeRange {M1 M10} \
            -targetViaLayerRange {M1 M10} \
            -allowLayerChange 1 \
            -allowJogging 1
    }
    catch {
        sroute -nets {VDD VSS} -connect {floatingStripe} \
            -floatingStripeTarget {stripe ring} \
            -layerChangeRange {M1 M10} \
            -targetViaLayerRange {M1 M10} \
            -allowLayerChange 1
    }
    catch {routePGPinUseSignalRoute -maxFanout 1}
}

restoreDesign $base_enc soc_top
soc_delete_perimeter_cells
soc_insert_foundrystyle_perimeter
soc_refresh_pg_connectivity
soc_repair_pg_routes

set endcap_rpt [file join $pnr_out_dir verify_endcap.rpt]
set tap_rpt [file join $pnr_out_dir verify_welltap.rpt]
verifyEndCap -report $endcap_rpt
verifyWellTap -report $tap_rpt

set drc_rpt [file join $pnr_out_dir drc_with_sram_iter0.rpt]
verify_drc -limit 10000 -report $drc_rpt

set conn_regular_rpt [file join $pnr_out_dir lvs_connectivity_regular.rpt]
set conn_special_rpt [file join $pnr_out_dir lvs_connectivity_special.rpt]
verifyConnectivity -type regular -error 1000 -warning 100 -report $conn_regular_rpt
verifyConnectivity -type special -noAntenna -error 1000 -warning 100 -report $conn_special_rpt

set antenna_rpt [file join $pnr_out_dir lvs_process_antenna.rpt]
catch {verifyProcessAntenna -report $antenna_rpt}

saveDesign [file join $pnr_out_dir with_sram_final.enc]
puts "BOUNDARY_REFIT_SUMMARY DRC=[parse_drc_violations $drc_rpt] REG=[parse_connectivity_errors $conn_regular_rpt] SPC=[parse_connectivity_errors $conn_special_rpt] ANT=[parse_antenna_violations $antenna_rpt]"
exit
