# Focused PG repair experiment on an existing routed checkpoint.
# Goal: add the vendor-style lower PG mesh (M3/M2/M1) and measure
# whether special connectivity collapses without rerunning full PnR.

set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]
set repair_src_enc [expr {
    [info exists ::env(SOC_REPAIR_SRC_ENC)] && $::env(SOC_REPAIR_SRC_ENC) ne ""
    ? [file normalize $::env(SOC_REPAIR_SRC_ENC)]
    : [file join $proj_root pd innovus_m8pins_vendorboundary_20260409 with_sram_route.enc]
}]
set repair_out_dir [expr {
    [info exists ::env(SOC_REPAIR_OUT_DIR)] && $::env(SOC_REPAIR_OUT_DIR) ne ""
    ? [file normalize $::env(SOC_REPAIR_OUT_DIR)]
    : [file join $proj_root pd innovus_m8pins_vendorboundary_pgfix_lower_20260409]
}]
file mkdir $repair_out_dir

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

proc parse_connectivity_errors {rpt} {
    if {![file exists $rpt]} {
        return -1
    }
    set content [read_text_file $rpt]
    if {[regexp -nocase {Found\s+no\s+problems\s+or\s+warnings\.} $content]} {
        return 0
    }
    if {[regexp {([0-9]+)\s+Problem\(s\)} $content -> num]} {
        return $num
    }
    return -1
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

proc createPowerStripe {region direction layer nets offset width spacing pitch} {
    variable curRegionBKG

    if {[lindex $nets 1] > 1} {
        set spacing [lrepeat [expr {[lindex $nets 1] - 1}] $spacing]
    }
    set nets      [lrepeat [lindex $nets 1] [lindex $nets 0]]
    set direction [expr {$direction eq "H" ? "horizontal" : "vertical"}]
    set blockage  [expr {[info exists curRegionBKG($region)] ? $curRegionBKG($region) : ""}]
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

proc soc_route_pg {} {
    setSrouteMode -viaConnectToShape {ring stripe}
    sroute -nets {VDD VSS} -connect {corePin blockPin} \
        -corePinTarget {ring stripe} \
        -blockPinTarget {ring stripe} \
        -layerChangeRange {M1 M10} \
        -allowLayerChange 1 \
        -allowJogging 1
}

puts "Restoring routed checkpoint: $repair_src_enc"
if {[file isdirectory $repair_src_enc]} {
    set restore_target $repair_src_enc
} elseif {[file exists "${repair_src_enc}.dat"]} {
    set restore_target "${repair_src_enc}.dat"
} else {
    set restore_target $repair_src_enc
}
puts "Resolved restore target: $restore_target"
restoreDesign $restore_target soc_top
soc_refresh_pg_connectivity
initializeRegionBKG

puts "Adding vendor-style lower PG mesh (M3/M2/M1)..."
createPowerStripe STD V M3 [list VDD 1] 0.261 0.038 0 2.520
createPowerStripe STD H M2 [list VDD 1] 0.544 0.064 0 1.152
createPowerStripe STD H M1 [list VDD 1] 0.531 0.090 0 1.152
createPowerStripe STD V M3 [list VSS 1] 1.521 0.038 0 2.520
createPowerStripe STD H M2 [list VSS 1] -0.032 0.064 0 1.152
createPowerStripe STD H M1 [list VSS 1] -0.045 0.090 0 1.152
P_POST_VIA_DROPPING M1 PG

puts "Refreshing PG routing to ring/stripe targets..."
soc_route_pg

set drc_rpt [file join $repair_out_dir drc_pgrepair.rpt]
set reg_rpt [file join $repair_out_dir lvs_connectivity_regular_pgrepair.rpt]
set spc_rpt [file join $repair_out_dir lvs_connectivity_special_pgrepair.rpt]

verify_drc -limit 10000 -report $drc_rpt
verifyConnectivity -type regular -error 1000 -warning 100 -report $reg_rpt
verifyConnectivity -type special -noAntenna -error 1000 -warning 100 -report $spc_rpt

set drc_viol [parse_drc_violations $drc_rpt]
set reg_err  [parse_connectivity_errors $reg_rpt]
set spc_err  [parse_connectivity_errors $spc_rpt]

saveDesign [file join $repair_out_dir with_sram_pgrepair.enc]

puts "PG repair summary:"
puts "  DRC     : $drc_viol"
puts "  regular : $reg_err"
puts "  special : $spc_err"
puts "  saved   : [file join $repair_out_dir with_sram_pgrepair.enc]"

exit
