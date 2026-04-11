set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]

set base_pnr_dir [expr {[info exists ::env(SOC_BASE_PNR_DIR)] && $::env(SOC_BASE_PNR_DIR) ne "" ? [file normalize $::env(SOC_BASE_PNR_DIR)] : [file join $proj_root pd innovus_foundrytap_20260410]}]
set route_enc [expr {[info exists ::env(SOC_ROUTE_ENC)] && $::env(SOC_ROUTE_ENC) ne "" ? [file normalize $::env(SOC_ROUTE_ENC)] : [file join $base_pnr_dir with_sram_route.enc.dat]}]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd innovus_foundrytap_postfix_20260410]}]
file mkdir $pnr_out_dir

proc read_text_file {path} {
    set fp [open $path r]
    set data [read $fp]
    close $fp
    return $data
}

proc fail_flow {code msg} {
    puts "ERROR: $msg"
    exit $code
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

proc soc_insert_boundary_repairs {} {
    setEndCapMode -reset
    setEndCapMode \
        -prefix ECOEC \
        -rightEdge {BOUNDARY_LEFTBWP16P90LVT} \
        -leftEdge {BOUNDARY_RIGHTBWP16P90LVT} \
        -leftTopCorner {BOUNDARY_PCORNERBWP16P90LVT} \
        -leftBottomCorner {BOUNDARY_NCORNERBWP16P90LVT} \
        -topEdge {BOUNDARY_PROW1BWP16P90LVT BOUNDARY_PROW2BWP16P90LVT BOUNDARY_PROW3BWP16P90LVT BOUNDARY_PROW4BWP16P90LVT} \
        -bottomEdge {BOUNDARY_NROW1BWP16P90LVT BOUNDARY_NROW2BWP16P90LVT BOUNDARY_NROW3BWP16P90LVT BOUNDARY_NROW4BWP16P90LVT} \
        -rightTopEdge {FILL3BWP16P90LVT} \
        -rightBottomEdge {FILL3BWP16P90LVT} \
        -fitGap true \
        -boundary_tap true
    set_well_tap_mode \
        -rule 50.76 \
        -bottom_tap_cell {BOUNDARY_NTAPBWP16P90LVT_VPP_VSS} \
        -top_tap_cell {BOUNDARY_PTAPBWP16P90LVT_VPP_VSS} \
        -cell {TAPCELLBWP16P90LVT_VPP_VSS}
    catch {addEndCap -prefix ECOEC} msg
    puts "addEndCap repair: $msg"

    set_well_tap_mode -reset
    set_well_tap_mode -insert_cells {{TAPCELLBWP16P90LVT_VPP_VSS rule 50.76}}
    catch {addWellTap -checkerBoard} msg
    puts "addWellTap repair: $msg"
}

proc soc_route_boundary_vpp_pgpins {} {
    setNanoRouteMode -routeAllowPowerGroundPin true
    catch {setAttribute -net VDD -skip_routing false}
    catch {setPGPinUseSignalRoute TAPCELL*:VPP BOUNDARY_*TAP*:VPP}
    set trunk_ndr [dbGet head.rules.name TrunkNDR -e]
    if {$trunk_ndr ne ""} {
        catch {
            setAttribute -net VDD \
                -avoid_detour true \
                -weight 20 \
                -non_default_rule TrunkNDR \
                -pattern trunk \
                -bottom_preferred_routing_layer 8 \
                -top_preferred_routing_layer 9
        }
        catch {routePGPinUseSignalRoute -maxFanout 1 -nonDefaultRule TrunkNDR}
    } else {
        catch {routePGPinUseSignalRoute -maxFanout 1}
    }
}

proc soc_repair_pg_routes {} {
    setSrouteMode -viaConnectToShape {ring stripe}
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

proc soc_get_design_bbox {} {
    set bbox_raw [get_db designs .bbox]
    set bbox [join $bbox_raw]
    if {[llength $bbox] != 4} {
        fail_flow 13 "Unexpected design bbox format: $bbox_raw"
    }
    return $bbox
}

proc soc_add_fill_region_if_valid {layers llx lly urx ury} {
    if {$urx <= $llx || $ury <= $lly} { return }
    addMetalFill -layer $layers -timingAware sta -area "$llx $lly $urx $ury"
}

proc soc_add_fill_with_trap_m4_keepout {llx lly urx ury} {
    set fill_ko_llx 143.45
    set fill_ko_lly 94.35
    set fill_ko_urx 144.15
    set fill_ko_ury 95.45
    set sram_ko_llx 104.30
    set sram_ko_lly 60.80
    set sram_ko_urx 106.10
    set sram_ko_ury 65.40

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

restoreDesign $route_enc soc_top
soc_insert_boundary_repairs
soc_refresh_pg_connectivity
soc_repair_pg_routes
soc_route_boundary_vpp_pgpins

set endcap_rpt [file join $pnr_out_dir verify_endcap.rpt]
set tap_rpt [file join $pnr_out_dir verify_welltap.rpt]
verifyEndCap -report $endcap_rpt
verifyWellTap -report $tap_rpt

soc_insert_standard_cell_fillers
soc_refresh_pg_connectivity

set bbox [soc_get_design_bbox]
soc_add_fill_with_trap_m4_keepout [lindex $bbox 0] [lindex $bbox 1] [lindex $bbox 2] [lindex $bbox 3]

set max_eco_iters 8
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

set conn_regular_rpt [file join $pnr_out_dir lvs_connectivity_regular.rpt]
set conn_special_rpt [file join $pnr_out_dir lvs_connectivity_special.rpt]
verifyConnectivity -type regular -error 1000 -warning 100 -report $conn_regular_rpt
verifyConnectivity -type special -noAntenna -error 1000 -warning 100 -report $conn_special_rpt

set antenna_rpt [file join $pnr_out_dir lvs_process_antenna.rpt]
catch {verifyProcessAntenna -report $antenna_rpt}

saveDesign [file join $pnr_out_dir with_sram_final.enc]
puts "POSTROUTE_FINALIZE_SUMMARY DRC=[parse_drc_violations $drc_rpt] REG=[parse_connectivity_errors $conn_regular_rpt] SPC=[parse_connectivity_errors $conn_special_rpt] ANT=[parse_antenna_violations $antenna_rpt]"
exit
