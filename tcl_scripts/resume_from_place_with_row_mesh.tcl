# Resume the vendor-boundary clean place checkpoint, add the lower PG mesh,
# then finish CTS/route/signoff on top of it.

set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]

set base_pnr_out_dir [expr {[info exists ::env(SOC_BASE_PNR_OUT_DIR)] && $::env(SOC_BASE_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_BASE_PNR_OUT_DIR)] : [file join $proj_root pd innovus_m8pins_vendorboundary_20260409]}]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd innovus_resume_from_place_with_row_mesh]}]
set base_place_enc [file join $base_pnr_out_dir with_sram_place.enc.dat]
set include_m1_mesh [expr {![info exists ::env(SOC_ROW_MESH_INCLUDE_M1)] || ($::env(SOC_ROW_MESH_INCLUDE_M1) ne "" && $::env(SOC_ROW_MESH_INCLUDE_M1) ne "0")}]
set skip_metal_fill [expr {[info exists ::env(SOC_SKIP_METAL_FILL)] && $::env(SOC_SKIP_METAL_FILL) ne "" && $::env(SOC_SKIP_METAL_FILL) ne "0"}]
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
    if {![file exists $rpt]} {
        return -1
    }
    set content [read_text_file $rpt]
    if {[regexp -nocase {No\s+DRC\s+violations\s+were\s+found} $content]} {
        return 0
    }
    if {[regexp -nocase {No\s+violations\s+were\s+found} $content]} {
        return 0
    }
    if {[regexp {Total\s+Violations\s*:\s*([0-9]+)} $content -> num]} {
        return $num
    }
    return -1
}

proc parse_connectivity_errors {rpt} {
    if {![file exists $rpt]} {
        return -1
    }
    set content [read_text_file $rpt]
    if {[regexp -nocase {Found\s+no\s+problems\s+or\s+warnings\.} $content]} {
        return 0
    }
    set total 0
    foreach line [split $content "\n"] {
        if {[regexp {^\s*([0-9]+)\s+Problem\(s\)} $line -> num]} {
            incr total $num
        }
    }
    if {$total > 0} {
        return $total
    }
    if {[regexp -nocase {Total\s+(Regular|Special)\s+Net\s+Errors\s*:\s*([0-9]+)} $content -> _ num]} {
        return $num
    }
    return -1
}

proc parse_antenna_violations {rpt} {
    if {![file exists $rpt]} {
        return -1
    }
    set content [read_text_file $rpt]
    if {[regexp -nocase {No\s+Violations\s+Found} $content]} {
        return 0
    }
    if {[regexp -nocase {Verification\s+Complete\s*:\s*([0-9]+)\s+Violations} $content -> num]} {
        return $num
    }
    if {[regexp -nocase {Total\s+number\s+of\s+process\s+antenna\s+violations\s*=\s*([0-9]+)} $content -> num]} {
        return $num
    }
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

variable curRegionBKG

proc P_VIA_GEN_MODE {} {
    setViaGenMode -reset
    setViaGenMode \
        -ignore_DRC 0 \
        -allow_via_expansion 0 \
        -extend_out_wire_end 1 \
        -inherit_wire_status 1 \
        -keep_existing_via 2 \
        -partial_overlap_threshold 1 \
        -allow_wire_shape_change 0 \
        -keep_fixed_via 1 \
        -optimize_cross_via 1 \
        -disable_via_merging 1 \
        -use_cce 1 \
        -use_fgc 1
}

proc P_POST_VIA_DROPPING {layer object {cellName "TS*"}} {
    set topLayerNum [expr {[dbget [dbget head.layers.name $layer -p].num] + 1}]
    set topLayer    [dbget [dbget head.layers.num $topLayerNum -p].name -e]

    setViaGenMode -reset
    setViaGenMode \
        -ignore_DRC 0 \
        -allow_via_expansion 0 \
        -extend_out_wire_end 1 \
        -inherit_wire_status 1 \
        -keep_existing_via 2 \
        -partial_overlap_threshold 1 \
        -allow_wire_shape_change 0 \
        -keep_fixed_via 1 \
        -optimize_cross_via 1 \
        -disable_via_merging 1 \
        -use_cce 1 \
        -use_fgc 1

    if {$object eq "PG"} {
        deselectAll
        select_obj [dbGet top.pgNets.sWires.layer.name $topLayer -p2]
        editPowerVia \
            -bottom_layer M1 \
            -top_layer M2 \
            -selected_wires 1 \
            -exclude_stack_vias 0 \
            -add_vias 1 \
            -orthogonal_only 0 \
            -via_using_exact_crossover_size 1 \
            -uda "VIA12_Manual" \
            -skip_via_on_pin {pad cover} \
            -skip_via_on_wire_shape {Blockring Corewire Blockwire Iowire Padring Ring Fillwire Noshape}
        deselectAll
    } elseif {$object eq "BLK"} {
        set blkBoxes [dbget [dbget top.insts.cell.name $cellName -p2].boxes -e]
        foreach box $blkBoxes {
            editPowerVia \
                -skip_via_on_pin {Pad Standardcell} \
                -skip_via_on_wire_shape {Ring Blockring Followpin Corewire Blockwire Iowire Padring Fillwire Noshape} \
                -bottom_layer $layer \
                -skip_via_on_wire_status {Fixed Cover Shield} \
                -add_vias 1 \
                -top_layer $topLayer \
                -area $box
        }
    }
}

proc P_PG_GEN_MODE {layer} {
    set topLayerNum [expr {[dbget [dbget head.layers.name $layer -p].num] + 1}]
    set topLayer    [dbget [dbget head.layers.num $topLayerNum -p].name -e]

    setAddStripeMode -reset
    setAddStripeMode \
        -use_fgc 1 \
        -remove_floating_stripe_over_block false \
        -stacked_via_bottom_layer $layer \
        -stacked_via_top_layer $topLayer \
        -keep_pitch_after_snap false \
        -via_using_exact_crossover_size false \
        -ignore_nondefault_domains true \
        -skip_via_on_pin {Pad Block Cover Standardcell Physicalpin} \
        -stapling_nets_style end_to_end \
        -remove_floating_stapling true
    setAddStripeMode -ignore_DRC 0
}

proc initializeRegionBKG {} {
    variable curRegionBKG
    array unset curRegionBKG

    set Die  [dbget top.fplan.box -e]
    set Core [dbget top.fplan.coreBox -e]
    set STD  [dbget top.fplan.rows.box -e]

    set curRegionBKG(Core) [dbshape $Die ANDNOT $Core -output rect]
    set curRegionBKG(STD)  [dbshape $Die ANDNOT [dbShape $STD SIZEY 0.1] -output rect]
}

proc createPowerStripe {region direction layer nets offset width spacing pitch {extra_blockage ""}} {
    variable curRegionBKG

    if {[lindex $nets 1] > 1} {
        set spacing [lrepeat [expr {[lindex $nets 1] - 1}] $spacing]
    }
    set nets      [lrepeat [lindex $nets 1] [lindex $nets 0]]
    set direction [expr {$direction eq "H" ? "horizontal" : "vertical"}]
    set blockage  [expr {[info exists curRegionBKG($region)] ? $curRegionBKG($region) : ""}]
    if {$extra_blockage ne ""} {
        set blockage [concat $blockage $extra_blockage]
    }
    set Die       [dbget top.fplan.box -e]

    P_VIA_GEN_MODE
    P_PG_GEN_MODE $layer

    addStripe \
        -area $Die \
        -area_blockage $blockage \
        -direction $direction \
        -layer $layer \
        -nets $nets \
        -start_offset $offset \
        -width $width \
        -spacing $spacing \
        -set_to_set_distance $pitch \
        -skip_via_on_wire_shape {} \
        -snap_wire_center_to_grid Grid \
        -uda PG_STR
}

proc soc_get_m3_short_keepouts {} {
    set core [dbget top.fplan.coreBox -e]
    set lly  [lindex $core 1]
    set ury  [lindex $core 3]
    set rects {}

    # Route-stage residuals cluster on a small set of M3 PG columns that short
    # into local signal tracks. Widen the keepouts slightly so the row mesh
    # skips those columns for both VDD and VSS.
    foreach xc {112.454 132.614 145.192 152.776 169.158 172.934 193.094} {
        set halfw 0.180
        lappend rects [list [expr {$xc - $halfw}] $lly [expr {$xc + $halfw}] $ury]
    }
    return $rects
}

proc soc_get_m2_pg_keepouts {} {
    set rects {}

    # Avoid pushing M2 PG stripes through the dense CORDIC pipeline cluster.
    lappend rects [list 139.45 179.95 143.95 198.25]

    # Avoid tiny stripe endpoints at the SRAM-side cut-row boundary.
    lappend rects [list 61.50 163.35 61.82 166.95]

    return $rects
}

proc soc_add_sram_pg_hotspot_blockages {} {
    # Keep block-pin sroute off the two SRAM-edge M4 windows that repeatedly
    # turn into span/minstep/minwidth residuals after row-mesh reroute.
    createRouteBlk -name sram_pg_m4_hotspot_mid  -layer {M4} -box {104.78 118.33 105.24 118.72}
    createRouteBlk -name sram_pg_m4_hotspot_high -layer {M4} -box {105.10 166.45 105.30 168.25}
    createRouteBlk -name sram_pg_m4_hotspot_low  -layer {M4} -box {61.84 61.58 62.24 67.20}
    createRouteBlk -name sram_pg_m3_hotspot_mid  -layer {M3} -box {105.00 118.34 105.18 118.54}
}

proc soc_add_row_pg_mesh {} {
    initializeRegionBKG
    set m3_keepouts [soc_get_m3_short_keepouts]
    set m2_keepouts [soc_get_m2_pg_keepouts]
    createPowerStripe STD V M3 [list VDD 1] 0.261 0.038 0 2.520 $m3_keepouts
    createPowerStripe STD H M2 [list VDD 1] 0.544 0.064 0 1.152 $m2_keepouts
    createPowerStripe STD V M3 [list VSS 1] 1.521 0.038 0 2.520 $m3_keepouts
    createPowerStripe STD H M2 [list VSS 1] -0.032 0.064 0 1.152 $m2_keepouts
    if {$::include_m1_mesh} {
        createPowerStripe STD H M1 [list VDD 1] 0.531 0.090 0 1.152
        createPowerStripe STD H M1 [list VSS 1] -0.045 0.090 0 1.152
        P_POST_VIA_DROPPING M1 PG
    }
}

proc soc_add_sparse_pg_backbone {} {
    initializeRegionBKG
    createPowerStripe STD V M5 [list VDD 1] 7.560 0.080 0 30.240
    createPowerStripe STD V M5 [list VSS 1] 22.680 0.080 0 30.240
}

proc soc_route_pg {} {
    setSrouteMode -viaConnectToShape {ring stripe}
    sroute -nets {VDD VSS} -connect {corePin} \
      -corePinTarget {ring stripe} \
      -layerChangeRange {M1 M10} \
      -targetViaLayerRange {M1 M10} \
      -allowLayerChange 1 \
      -allowJogging 1
    sroute -nets {VDD VSS} -connect {blockPin} \
      -inst u_sram/u_sram_macro \
      -blockPinTarget {stripe ring} \
      -blockPinLayerRange {M4 M10} \
      -layerChangeRange {M4 M10} \
      -targetViaLayerRange {M4 M10} \
      -allowLayerChange 1 \
      -allowJogging 1
    sroute -nets {VDD VSS} -connect {floatingStripe} \
      -floatingStripeTarget {stripe ring} \
      -layerChangeRange {M1 M10} \
      -targetViaLayerRange {M1 M10} \
      -allowLayerChange 1
}

proc soc_route_boundary_vpp_pgpins {} {
    setNanoRouteMode -routeAllowPowerGroundPin true
    catch {setAttribute -net VDD -skip_routing false}
    set trunk_ndr [dbGet head.rules.name TrunkNDR -e]
    catch {setPGPinUseSignalRoute TAPCELL*:VPP BOUNDARY_*TAP*:VPP}
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
    if {$urx <= $llx || $ury <= $lly} {
        return
    }
    addMetalFill -layer $layers -timingAware sta -area "$llx $lly $urx $ury"
}

proc soc_add_fill_with_trap_m4_keepout {llx lly urx ury} {
    set fill_ko_llx 143.45
    set fill_ko_lly 94.35
    set fill_ko_urx 144.15
    set fill_ko_ury 95.45

    soc_add_fill_region_if_valid {M1 M2 M3 M6} $llx $lly $urx $ury
    soc_add_fill_region_if_valid {M5} $llx $lly $urx $fill_ko_lly
    soc_add_fill_region_if_valid {M5} $llx $fill_ko_ury $urx $ury
    soc_add_fill_region_if_valid {M5} $llx $fill_ko_lly $fill_ko_llx $fill_ko_ury
    soc_add_fill_region_if_valid {M5} $fill_ko_urx $fill_ko_lly $urx $fill_ko_ury
    soc_add_fill_region_if_valid {M4} $llx $lly $urx $ury
}

puts ""
puts "=========================================="
puts "RESUME FROM CLEAN PLACE + LOWER PG MESH"
puts "=========================================="
puts "Base place checkpoint: $base_place_enc"
puts "Output dir: $pnr_out_dir"
puts ""

if {![file exists $base_place_enc]} {
    fail_flow 10 "Missing base place checkpoint: $base_place_enc"
}

restoreDesign $base_place_enc soc_top

soc_refresh_pg_connectivity
soc_add_sram_pg_hotspot_blockages
soc_add_sparse_pg_backbone
soc_add_row_pg_mesh
saveDesign [file join $pnr_out_dir with_sram_place_pgmesh.enc]

setNanoRouteMode -droutePostRouteSpreadWire true
setNanoRouteMode -routeWithViaInPin true
setNanoRouteMode -routeWithViaOnlyForStandardCellPin true
setNanoRouteMode -drouteUseMultiCutViaEffort high
setNanoRouteMode -routeWithSiDriven false
setNanoRouteMode -routeWithTimingDriven false
setNanoRouteMode -drouteFixAntenna true
setNanoRouteMode -routeBottomRoutingLayer 1
setNanoRouteMode -routeTopRoutingLayer 6

soc_route_pg

ccopt_design -cts
saveDesign [file join $pnr_out_dir with_sram_cts.enc]

soc_refresh_pg_connectivity
soc_route_boundary_vpp_pgpins

routeDesign
saveDesign [file join $pnr_out_dir with_sram_route.enc]

soc_insert_standard_cell_fillers
soc_refresh_pg_connectivity
soc_route_pg
saveDesign [file join $pnr_out_dir with_sram_postpg.enc]

if {!$skip_metal_fill} {
    set bbox [soc_get_design_bbox]
    set llx [lindex $bbox 0]
    set lly [lindex $bbox 1]
    set urx [lindex $bbox 2]
    set ury [lindex $bbox 3]
    soc_add_fill_with_trap_m4_keepout $llx $lly $urx $ury
} else {
    puts "Skipping metal fill before DRC/connectivity gates"
}

set max_eco_iters 8
set eco_iter 0
set drc_rpt [file join $pnr_out_dir drc_with_sram_iter0.rpt]
verify_drc -limit 10000 -report $drc_rpt
set drc_viol [parse_drc_violations $drc_rpt]
if {$drc_viol < 0} {
    fail_flow 20 "Unable to parse DRC report: $drc_rpt"
}
puts "Initial DRC violations: $drc_viol"

while {$drc_viol > 0 && $eco_iter < $max_eco_iters} {
    incr eco_iter
    puts "Running ECO DRC-fix iteration $eco_iter..."
    catch {ecoRoute -fix_drc} eco_msg

    set iter_rpt [file join $pnr_out_dir drc_with_sram_iter${eco_iter}.rpt]
    verify_drc -limit 10000 -report $iter_rpt
    set drc_viol [parse_drc_violations $iter_rpt]
    if {$drc_viol < 0} {
        fail_flow 21 "Unable to parse DRC report: $iter_rpt"
    }
    puts "Iteration $eco_iter DRC violations: $drc_viol"
}

if {$drc_viol > 0} {
    fail_flow 22 "DRC gate failed after $max_eco_iters ECO iterations ($drc_viol remain)."
}
puts "DRC gate: PASS (0 violations)"

set conn_regular_rpt [file join $pnr_out_dir lvs_connectivity_regular.rpt]
verifyConnectivity -type regular -error 1000 -warning 100 -report $conn_regular_rpt
set regular_errors [parse_connectivity_errors $conn_regular_rpt]
if {$regular_errors < 0} {
    fail_flow 30 "Unable to parse regular connectivity report: $conn_regular_rpt"
}

set conn_special_rpt [file join $pnr_out_dir lvs_connectivity_special.rpt]
verifyConnectivity -type special -noAntenna -error 1000 -warning 100 -report $conn_special_rpt
set special_errors [parse_connectivity_errors $conn_special_rpt]
if {$special_errors < 0} {
    fail_flow 31 "Unable to parse special connectivity report: $conn_special_rpt"
}

if {$regular_errors != 0 || $special_errors != 0} {
    fail_flow 32 "Connectivity gate failed (regular=$regular_errors, special=$special_errors)."
}
puts "Connectivity gates: PASS (regular=0, special=0)"

set antenna_rpt [file join $pnr_out_dir lvs_process_antenna.rpt]
catch {verifyProcessAntenna -report $antenna_rpt} antenna_msg
set antenna_viol [parse_antenna_violations $antenna_rpt]
if {$antenna_viol < 0} {
    fail_flow 33 "Unable to parse antenna report: $antenna_rpt"
}
if {$antenna_viol != 0} {
    fail_flow 34 "Antenna gate failed ($antenna_viol violations)."
}
puts "Antenna gate: PASS (0 violations)"

saveDesign [file join $pnr_out_dir with_sram_final.enc]
puts "Resume-from-place flow: PASS"
exit
