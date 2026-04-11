set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]

set base_enc [expr {[info exists ::env(SOC_BASE_ENC)] && $::env(SOC_BASE_ENC) ne "" ? [file normalize $::env(SOC_BASE_ENC)] : [file join $proj_root pd innovus_m8pins_20260409 with_sram_final.enc.dat]}]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd innovus_m8pins_boundaryrefit_nonlvt_20260410]}]
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

proc soc_delete_fillers {} {
    foreach pat {FILL* DCAP*} {
        set insts [dbGet -u -e [dbGet -p2 top.insts.cell.name $pat]]
        set names [dbGet -u -e $insts.name]
        if {[llength $names] > 0} {
            puts "Deleting [llength $names] $pat instances"
            deleteInst $names
        }
    }
}

proc soc_insert_boundary_refit {} {
    setEndCapMode -reset
    setEndCapMode \
        -prefix ECOEC \
        -rightEdge {BOUNDARY_LEFTBWP16P90} \
        -leftEdge {BOUNDARY_RIGHTBWP16P90} \
        -leftTopCorner {BOUNDARY_PCORNERBWP16P90} \
        -leftBottomCorner {BOUNDARY_NCORNERBWP16P90} \
        -topEdge {BOUNDARY_PROW1BWP16P90 BOUNDARY_PROW2BWP16P90 BOUNDARY_PROW3BWP16P90 BOUNDARY_PROW4BWP16P90} \
        -bottomEdge {BOUNDARY_NROW1BWP16P90 BOUNDARY_NROW2BWP16P90 BOUNDARY_NROW3BWP16P90 BOUNDARY_NROW4BWP16P90} \
        -leftTopEdge {FILL3BWP16P90} \
        -leftBottomEdge {FILL3BWP16P90} \
        -rightTopEdge {FILL3BWP16P90} \
        -rightBottomEdge {FILL3BWP16P90} \
        -fitGap true
    catch {addEndCap -prefix ECOEC} msg
    puts "addEndCap refit: $msg"
}

proc soc_insert_standard_cell_fillers {} {
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
    setPlaceMode -place_detail_use_no_diffusion_one_site_filler true
    setPlaceMode -place_detail_no_filler_without_implant true
    setPlaceMode -place_detail_check_diffusion_forbidden_spacing true
    setFillerMode -core $filler_cells -preserveUserOrder true -fitGap true \
        -corePrefix FILLER -add_fillers_with_drc false -check_signal_drc true
    addFiller
    checkFiller
    checkPlace
}

proc soc_repair_pg_routes {} {
    setNanoRouteMode -routeAllowPowerGroundPin true
    catch {
        sroute -nets {VDD VSS} -connect {corePin floatingStripe} \
            -corePinTarget {ring stripe} \
            -floatingStripeTarget {stripe ring} \
            -layerChangeRange {M1 M10} \
            -targetViaLayerRange {M1 M10} \
            -allowLayerChange 1 \
            -allowJogging 1
    }
}

restoreDesign $base_enc soc_top
soc_delete_fillers
soc_insert_boundary_refit
soc_insert_standard_cell_fillers
soc_refresh_pg_connectivity
soc_repair_pg_routes

set max_eco_iters 4
set eco_iter 0
set drc_rpt [file join $pnr_out_dir drc_with_sram_iter0.rpt]
verify_drc -limit 10000 -report $drc_rpt
set drc_viol [parse_drc_violations $drc_rpt]
while {$drc_viol > 0 && $eco_iter < $max_eco_iters} {
    incr eco_iter
    catch {ecoRoute -fix_drc}
    set drc_rpt [file join $pnr_out_dir drc_with_sram_iter${eco_iter}.rpt]
    verify_drc -limit 10000 -report $drc_rpt
    set drc_viol [parse_drc_violations $drc_rpt]
}

set endcap_rpt [file join $pnr_out_dir verify_endcap.rpt]
verifyEndCap -report $endcap_rpt

set conn_regular_rpt [file join $pnr_out_dir lvs_connectivity_regular.rpt]
set conn_special_rpt [file join $pnr_out_dir lvs_connectivity_special.rpt]
verifyConnectivity -type regular -error 1000 -warning 100 -report $conn_regular_rpt
verifyConnectivity -type special -noAntenna -error 1000 -warning 100 -report $conn_special_rpt

set antenna_rpt [file join $pnr_out_dir lvs_process_antenna.rpt]
catch {verifyProcessAntenna -report $antenna_rpt}

saveDesign [file join $pnr_out_dir with_sram_final.enc]
puts "M8PINS_BOUNDARY_REFIT_SUMMARY DRC=[parse_drc_violations $drc_rpt] REG=[parse_connectivity_errors $conn_regular_rpt] SPC=[parse_connectivity_errors $conn_special_rpt] ANT=[parse_antenna_violations $antenna_rpt]"
exit
