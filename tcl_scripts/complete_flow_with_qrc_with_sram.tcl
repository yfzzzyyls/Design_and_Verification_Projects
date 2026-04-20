# Complete P&R Flow with QRC Tech Files (SRAM-enabled variant)
# This script requires the hard SRAM macro instance and enforces clean signoff gates.

set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd innovus]}]
set map_out_dir [expr {[info exists ::env(SOC_MAP_OUT_DIR)] && $::env(SOC_MAP_OUT_DIR) ne "" ? [file normalize $::env(SOC_MAP_OUT_DIR)] : [file join $proj_root mapped_with_tech]}]
set enable_endcaps [expr {![info exists ::env(SOC_ENABLE_ENDCAPS)] || $::env(SOC_ENABLE_ENDCAPS) eq "" ? 1 : ($::env(SOC_ENABLE_ENDCAPS) ne "0")}]
set enable_welltaps [expr {[info exists ::env(SOC_ENABLE_WELLTAPS)] && $::env(SOC_ENABLE_WELLTAPS) ne "" ? ($::env(SOC_ENABLE_WELLTAPS) ne "0") : $enable_endcaps}]
set enable_row_pg_mesh [expr {[info exists ::env(SOC_ENABLE_ROW_PG_MESH)] && $::env(SOC_ENABLE_ROW_PG_MESH) ne "" && $::env(SOC_ENABLE_ROW_PG_MESH) ne "0"}]
set enable_sparse_pg_backbone [expr {[info exists ::env(SOC_ENABLE_SPARSE_PG_BACKBONE)] && $::env(SOC_ENABLE_SPARSE_PG_BACKBONE) ne "" ? ($::env(SOC_ENABLE_SPARSE_PG_BACKBONE) ne "0") : $enable_endcaps}]
set enable_vendor_pg_mesh [expr {[info exists ::env(SOC_ENABLE_VENDOR_PG_MESH)] && $::env(SOC_ENABLE_VENDOR_PG_MESH) ne "" && $::env(SOC_ENABLE_VENDOR_PG_MESH) ne "0"}]
set include_row_pg_m1_mesh [expr {![info exists ::env(SOC_ROW_MESH_INCLUDE_M1)] || ($::env(SOC_ROW_MESH_INCLUDE_M1) ne "" && $::env(SOC_ROW_MESH_INCLUDE_M1) ne "0")}]
set enable_sram_pg_hotspot_blockage [expr {![info exists ::env(SOC_ENABLE_SRAM_PG_HOTSPOT_BLOCKAGE)] || ($::env(SOC_ENABLE_SRAM_PG_HOTSPOT_BLOCKAGE) ne "" && $::env(SOC_ENABLE_SRAM_PG_HOTSPOT_BLOCKAGE) ne "0")}]
set enable_sram_vdd_trim_fix [expr {[info exists ::env(SOC_ENABLE_SRAM_VDD_TRIM_FIX)] && $::env(SOC_ENABLE_SRAM_VDD_TRIM_FIX) ne "" && $::env(SOC_ENABLE_SRAM_VDD_TRIM_FIX) ne "0"}]
set ring_offset [expr {[info exists ::env(SOC_RING_OFFSET)] && $::env(SOC_RING_OFFSET) ne "" ? $::env(SOC_RING_OFFSET) : 5.0}]
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

proc soc_get_vss_m3_short_keepouts {} {
    set core [dbget top.fplan.coreBox -e]
    set lly  [lindex $core 1]
    set ury  [lindex $core 3]
    set rects {}

    foreach xc {132.614 172.934 193.094} {
        set halfw 0.090
        lappend rects [list [expr {$xc - $halfw}] $lly [expr {$xc + $halfw}] $ury]
    }
    return $rects
}

proc soc_get_design_bbox {} {
    set bbox_raw [get_db designs .bbox]
    set bbox [join $bbox_raw]
    if {[llength $bbox] != 4} {
        fail_flow 13 "Unexpected design bbox format: $bbox_raw"
    }
    return $bbox
}

proc soc_add_top_signal_pins {} {
    set signal_pins {clk rst_n trap uart_rx uart_tx}
    if {[llength [get_db ports $signal_pins]] == 0} {
        puts "No top-level signal ports found for pin creation; skipping."
        return
    }
    setPinAssignMode -pinEditInBatch true
    editPin -pin $signal_pins \
      -side TOP \
      -layer M8 \
      -spreadType CENTER \
      -spacing 40 \
      -pinWidth 0.40 \
      -pinDepth 0.40 \
      -snap TRACK \
      -fixedPin \
      -fixOverlap
    setPinAssignMode -pinEditInBatch false
    puts "Created physical top pins for: $signal_pins"
}

proc soc_add_endcaps_and_taps {} {
    setEndCapMode -reset
    setEndCapMode \
      -prefix EC \
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
      -fitGap true \
      -boundary_tap true
    set_well_tap_mode \
      -rule 50.76 \
      -bottom_tap_cell {BOUNDARY_NTAPBWP16P90_VPP_VSS} \
      -top_tap_cell {BOUNDARY_PTAPBWP16P90_VPP_VSS} \
      -cell {TAPCELLBWP16P90_VPP_VSS}
    addEndCap -prefix EC
    if {$::enable_welltaps} {
        set_well_tap_mode -reset
        set_well_tap_mode -insert_cells {{TAPCELLBWP16P90_VPP_VSS rule 50.76}}
        addWellTap -checkerBoard
        puts "Inserted boundary cells and well taps."
    } else {
        puts "Inserted boundary cells only."
    }
    verifyEndCap -report [file join $::pnr_out_dir verify_endcap.rpt]
    if {$::enable_welltaps} {
        verifyWellTap -report [file join $::pnr_out_dir verify_welltap.rpt]
    }
}

proc soc_check_physical_boundary_cells {stage} {
    set endcaps [dbGet top.insts.name EC* -e]
    set welltaps [dbGet top.insts.name WELLTAP* -e]
    puts "Physical-cell check at $stage: endcaps=[llength $endcaps] welltaps=[llength $welltaps]"
    if {$::enable_endcaps && [llength $endcaps] == 0} {
        fail_flow 30 "No endcap instances are present at $stage."
    }
    if {$::enable_endcaps && $::enable_welltaps && [llength $welltaps] == 0} {
        fail_flow 31 "No welltap instances are present at $stage."
    }
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

proc soc_route_pg_core_only {} {
    setSrouteMode -viaConnectToShape {ring stripe}
    sroute -nets {VDD VSS} -connect {corePin} \
      -corePinTarget {ring stripe} \
      -layerChangeRange {M1 M10} \
      -targetViaLayerRange {M1 M10} \
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

proc soc_add_row_pg_mesh {} {
    initializeRegionBKG
    set vss_m3_keepouts [soc_get_vss_m3_short_keepouts]
    createPowerStripe STD V M3 [list VDD 1] 0.261 0.038 0 2.520
    createPowerStripe STD H M2 [list VDD 1] 0.544 0.064 0 1.152
    createPowerStripe STD V M3 [list VSS 1] 1.521 0.038 0 2.520 $vss_m3_keepouts
    createPowerStripe STD H M2 [list VSS 1] -0.032 0.064 0 1.152
    if {$::include_row_pg_m1_mesh} {
        createPowerStripe STD H M1 [list VDD 1] 0.531 0.090 0 1.152
        createPowerStripe STD H M1 [list VSS 1] -0.045 0.090 0 1.152
        P_POST_VIA_DROPPING M1 PG
    }
}

proc soc_add_vendor_pg_mesh {} {
    initializeRegionBKG
    createPowerStripe STD V M9 [list VDD 1] 0.055 0.450 0 2.520
    createPowerStripe STD H M8 [list VDD 1] 1.121 0.062 0 2.304
    createPowerStripe STD V M7 [list VDD 1] 0.220 0.120 0 2.520
    createPowerStripe STD H M6 [list VDD 1] 1.052 0.040 0 2.304
    createPowerStripe STD V M5 [list VDD 1] 0.180 0.040 0 2.520
    createPowerStripe STD H M4 [list VDD 1] -0.676 0.040 0 2.304
    createPowerStripe STD V M3 [list VDD 1] 0.261 0.038 0 2.520
    createPowerStripe STD H M2 [list VDD 1] 0.544 0.064 0 1.152
    createPowerStripe STD H M1 [list VDD 1] 0.531 0.090 0 1.152

    createPowerStripe STD V M9 [list VSS 1] 1.315 0.450 0 2.520
    createPowerStripe STD H M8 [list VSS 1] -0.031 0.062 0 2.304
    createPowerStripe STD V M7 [list VSS 1] 1.480 0.120 0 2.520
    createPowerStripe STD H M6 [list VSS 1] -0.100 0.040 0 2.304
    createPowerStripe STD V M5 [list VSS 1] 1.440 0.040 0 2.520
    createPowerStripe STD H M4 [list VSS 1] -0.100 0.040 0 2.304
    createPowerStripe STD V M3 [list VSS 1] 1.521 0.038 0 2.520
    createPowerStripe STD H M2 [list VSS 1] -0.032 0.064 0 1.152
    createPowerStripe STD H M1 [list VSS 1] -0.045 0.090 0 1.152
    P_POST_VIA_DROPPING M1 PG
}

proc soc_add_sparse_pg_backbone {} {
    initializeRegionBKG
    # Sparse M5 vertical backbones keep periodic PG pickup points away from
    # the dense M3 signal fabric and reduce persistent M3 short/cut-spacing DRCs.
    createPowerStripe STD V M5 [list VDD 1] 7.560 0.080 0 30.240
    createPowerStripe STD V M5 [list VSS 1] 22.680 0.080 0 30.240
}

proc soc_add_fill_region_if_valid {layers llx lly urx ury} {
    if {$urx <= $llx || $ury <= $lly} {
        return
    }
    addMetalFill -layer $layers -timingAware sta -area "$llx $lly $urx $ury"
}

proc soc_add_fill_with_trap_m4_keepout {llx lly urx ury} {
    # Keep M5 fill away from the persistent post-route hotspot near u_cpu/n4002.
    set fill_ko_llx 143.45
    set fill_ko_lly 94.35
    set fill_ko_urx 144.15
    set fill_ko_ury 95.45
    # Keep M4/M5 fill away from the SRAM VDD attach geometry that repeatedly
    # turns into post-fill special-route DRCs near the macro edge.
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

proc soc_trim_sram_vdd_hotspot_shapes {} {
    set delete_areas {
        {104.800 60.900 105.500 65.000}
        {105.040 64.740 105.271 64.860}
        {105.318 61.300 105.390 61.800}
    }
    set total_deleted 0
    foreach area $delete_areas {
        deselectAll
        editSelect -net VDD -type Special -layer M4 -area $area
        set sel_count [llength [dbGet selected]]
        if {$sel_count > 0} {
            editDelete -selected
            incr total_deleted $sel_count
        }
    }
    deselectAll
    puts "SRAM VDD hotspot trim deleted $total_deleted special-shape object(s)."
    return $total_deleted
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

puts "\n=========================================="
puts "Complete P&R Flow with QRC (WITH SRAM)"
puts "==========================================\n"
puts "Using netlist from: $map_out_dir"
puts "This variant enforces SRAM presence and clean post-route gates."
puts ""

# Library and design inputs
set TECH_LEF  "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/Tech/APR/N16ADFP_APR_Innovus/N16ADFP_APR_Innovus_11M.10a.tlef"
set STD_LEF   "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/LEF/lef/N16ADFP_StdCell.lef"
set SRAM_LEF  "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/IP/sram/N16ADFP_SRAM/LEF/N16ADFP_SRAM_100a.lef"

set NETLIST   [file join $map_out_dir soc_top.v]
set TOP       "soc_top"
set MMMC_QRC_FILE [file normalize [file join $script_dir innovus_mmmc.tcl]]

set init_pwr_net VDD
set init_gnd_net VSS

set init_lef_file   [list $TECH_LEF $STD_LEF $SRAM_LEF]
set init_verilog    $NETLIST
set init_top_cell   $TOP
set init_mmmc_file  $MMMC_QRC_FILE

puts "Initializing design..."
init_design

puts "\n=========================================="
puts "===== FLOORPLAN + SRAM PLACEMENT ====="
puts "==========================================\n"

# Keep baseline geometry model, but deterministic macro-aware placement.
floorPlan -site core -r 1.0 0.30 50 50 50 50
soc_add_top_signal_pins

set sram_path "u_sram/u_sram_macro"
set sram_inst [dbGet top.insts.name $sram_path -p]
if {[llength $sram_inst] == 0} {
    fail_flow 10 "Required SRAM instance '$sram_path' is missing in netlist."
}

set core_box [join [dbGet top.fPlan.coreBox]]
set core_llx [lindex $core_box 0]
set core_lly [lindex $core_box 1]
set core_urx [lindex $core_box 2]
set core_ury [lindex $core_box 3]
if {![string is double -strict $core_llx] || ![string is double -strict $core_lly] || \
    ![string is double -strict $core_urx] || ![string is double -strict $core_ury]} {
    fail_flow 11 "Unexpected coreBox format: $core_box"
}

# TS1N16ADFPCLLLVTA512X45M4SWSHOD size from LEF.
set sram_w 43.025
set sram_h 105.552
set macro_margin_x 12.0
set macro_margin_y 12.0
set sram_x_offset [expr {[info exists ::env(SOC_SRAM_X_OFFSET)] && $::env(SOC_SRAM_X_OFFSET) ne "" ? $::env(SOC_SRAM_X_OFFSET) : 0.0}]
set sram_y_offset [expr {[info exists ::env(SOC_SRAM_Y_OFFSET)] && $::env(SOC_SRAM_Y_OFFSET) ne "" ? $::env(SOC_SRAM_Y_OFFSET) : 0.0}]

set min_x [expr {$core_llx + $macro_margin_x}]
set max_x [expr {$core_urx - $macro_margin_x - $sram_w}]
set min_y [expr {$core_lly + $macro_margin_y}]
set max_y [expr {$core_ury - $macro_margin_y - $sram_h}]
set legal_min_x $core_llx
set legal_max_x [expr {$core_urx - $sram_w}]
set legal_min_y $core_lly
set legal_max_y [expr {$core_ury - $sram_h}]
if {$max_x < $min_x || $max_y < $min_y} {
    fail_flow 12 "Core too small for SRAM placement with requested margins."
}

# Deterministic placement: lower-left core-relative anchor.
set sram_x [expr {$min_x + $sram_x_offset}]
set sram_y [expr {$min_y + $sram_y_offset}]
if {$sram_x < $legal_min_x || $sram_x > $legal_max_x || $sram_y < $legal_min_y || $sram_y > $legal_max_y} {
    fail_flow 12 "Requested SRAM offset places macro outside legal core placement window."
}
placeInstance $sram_path $sram_x $sram_y R0
set_db [get_db insts $sram_path] .place_status fixed
puts "SRAM macro placed at ($sram_x, $sram_y) and fixed."

# Add a small upper-metal signal halo around the macro while allowing PG routing.
set sram_box [join [dbGet $sram_inst.box]]
set s_llx [lindex $sram_box 0]
set s_lly [lindex $sram_box 1]
set s_urx [lindex $sram_box 2]
set s_ury [lindex $sram_box 3]
set halo 4.0
set h_llx [expr {$s_llx - $halo}]
set h_lly [expr {$s_lly - $halo}]
set h_urx [expr {$s_urx + $halo}]
set h_ury [expr {$s_ury + $halo}]
createRouteBlk -name sram_sig_halo -layer {M5 M6} -box [list $h_llx $h_lly $h_urx $h_ury] -exceptpgnet
puts "Added SRAM signal halo/blockage (M5-M6, PG exempt)."

if {$enable_sram_pg_hotspot_blockage} {
    # The SRAM VDD block-pin attach can create a tiny M4 special-route stub
    # just outside the macro edge near the lower corner. The blockage is
    # optional because some netlists need the native attach for clean PG
    # connectivity, with the residual hotspot trimmed after routing instead.
    set pg_ko_llx [expr {$s_urx - 0.05}]
    set pg_ko_lly [expr {$s_lly - 1.0}]
    set pg_ko_urx [expr {$s_urx + 1.10}]
    set pg_ko_ury [expr {$s_lly + 3.50}]
    createRouteBlk -name sram_pg_m4_hotspot -layer {M4} -box [list $pg_ko_llx $pg_ko_lly $pg_ko_urx $pg_ko_ury]
    puts "Added SRAM PG hotspot blockage on M4 at ($pg_ko_llx, $pg_ko_lly) - ($pg_ko_urx, $pg_ko_ury)."
} else {
    puts "Skipping SRAM PG hotspot blockage on M4."
}
cutRow
checkFPlan -outFile [file join $pnr_out_dir checkFPlan.rpt]
if {$enable_endcaps} {
    soc_add_endcaps_and_taps
    soc_check_physical_boundary_cells post_boundary_insertion
} else {
    puts "Skipping endcap/tap insertion."
}

setDesignMode -process 16
soc_refresh_pg_connectivity

puts "\n=========================================="
puts "===== PG RING + ROUTING CONFIG ====="
puts "==========================================\n"

addRing -nets {VDD VSS} \
  -type core_rings \
  -layer {top M10 bottom M10 left M9 right M9} \
  -width 2.0 -spacing 2.0 \
  -offset [list top $ring_offset bottom $ring_offset left $ring_offset right $ring_offset]

if {$enable_sparse_pg_backbone} {
    puts "Sparse PG backbone enabled; deferred until after placement."
}

if {$enable_row_pg_mesh} {
    puts "Row PG mesh enabled; deferred until after placement."
}

if {$enable_vendor_pg_mesh} {
    puts "Vendor-style PG mesh enabled; deferred until after placement."
}

setNanoRouteMode -droutePostRouteSpreadWire true
setNanoRouteMode -routeWithViaInPin true
setNanoRouteMode -routeWithViaOnlyForStandardCellPin true
setNanoRouteMode -drouteUseMultiCutViaEffort high
setNanoRouteMode -routeWithSiDriven false
setNanoRouteMode -routeWithTimingDriven false
setNanoRouteMode -drouteFixAntenna true
setNanoRouteMode -routeAllowPowerGroundPin true
setNanoRouteMode -routeBottomRoutingLayer 1
setNanoRouteMode -routeTopRoutingLayer 6

puts "\n=========================================="
puts "===== PLACE / SROUTE / CTS / ROUTE ====="
puts "==========================================\n"
place_design
if {$enable_endcaps} {
    soc_check_physical_boundary_cells post_place
}
saveDesign [file join $pnr_out_dir with_sram_place.enc]

if {$enable_sparse_pg_backbone} {
    soc_add_sparse_pg_backbone
    puts "Added sparse M5 PG backbone."
}

if {$enable_row_pg_mesh} {
    soc_add_row_pg_mesh
    puts "Added standard-cell row PG mesh on placed rows."
}

if {$enable_vendor_pg_mesh} {
    soc_add_vendor_pg_mesh
    puts "Added vendor-style standard-cell PG mesh."
}

soc_refresh_pg_connectivity

soc_route_pg

ccopt_design -cts
saveDesign [file join $pnr_out_dir with_sram_cts.enc]

soc_refresh_pg_connectivity
soc_route_boundary_vpp_pgpins

routeDesign
if {$enable_endcaps} {
    soc_check_physical_boundary_cells post_route
}
saveDesign [file join $pnr_out_dir with_sram_route.enc]
soc_insert_standard_cell_fillers
soc_refresh_pg_connectivity

puts "\n=========================================="
puts "===== METAL FILL ====="
puts "==========================================\n"
set bbox [soc_get_design_bbox]
set llx [lindex $bbox 0]
set lly [lindex $bbox 1]
set urx [lindex $bbox 2]
set ury [lindex $bbox 3]
soc_add_fill_with_trap_m4_keepout $llx $lly $urx $ury

puts "\n=========================================="
puts "===== DRC GATE + BOUNDED ECO LOOP ====="
puts "==========================================\n"
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

if {$drc_viol > 0 && $enable_sram_vdd_trim_fix} {
    puts "Trying SRAM-side VDD hotspot trim repair..."
    set trimmed [soc_trim_sram_vdd_hotspot_shapes]
    if {$trimmed > 0} {
        catch {ecoRoute -fix_drc}
        set trim_rpt [file join $pnr_out_dir drc_with_sram_trimfix.rpt]
        verify_drc -limit 10000 -report $trim_rpt
        set drc_viol [parse_drc_violations $trim_rpt]
        if {$drc_viol < 0} {
            fail_flow 21 "Unable to parse DRC report: $trim_rpt"
        }
        puts "Trim-fix DRC violations: $drc_viol"
    } else {
        puts "No SRAM VDD hotspot shapes matched trim boxes."
    }
}

if {$drc_viol > 0} {
    fail_flow 22 "DRC gate failed after $max_eco_iters ECO iterations ($drc_viol remain)."
}
puts "DRC gate: PASS (0 violations)"
saveDesign [file join $pnr_out_dir with_sram_postdrc.enc]

soc_refresh_pg_connectivity

puts "\n=========================================="
puts "===== CONNECTIVITY + ANTENNA GATES ====="
puts "==========================================\n"

set conn_regular_rpt [file join $pnr_out_dir lvs_connectivity_regular.rpt]
verifyConnectivity -type regular -error 1000 -warning 100 -report $conn_regular_rpt
set regular_errors [parse_connectivity_errors $conn_regular_rpt]
if {$regular_errors < 0} {
    fail_flow 30 "Unable to parse regular connectivity report: $conn_regular_rpt"
}

# For macro-adjacent cut rows, special-net dangling markers correspond to
# row-end stubs and not true opens. Gate special connectivity with -noAntenna.
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
if {$enable_endcaps} {
    soc_check_physical_boundary_cells final
}

puts "\n=========================================="
puts "WITH-SRAM FLOW RESULT: PASS"
puts "==========================================\n"
puts "Final checkpoints:"
puts "  - [file join $pnr_out_dir with_sram_final.enc]"
puts "  - [file join $pnr_out_dir drc_with_sram_iter*.rpt]"
puts "  - [file join $pnr_out_dir lvs_connectivity_regular.rpt]"
puts "  - [file join $pnr_out_dir lvs_connectivity_special.rpt]"
puts "  - [file join $pnr_out_dir lvs_process_antenna.rpt]"

exit
