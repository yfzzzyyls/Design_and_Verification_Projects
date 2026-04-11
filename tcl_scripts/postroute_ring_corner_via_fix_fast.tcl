set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd postroute_ring_corner_via_fix_fast]}]
set route_enc [expr {[info exists ::env(SOC_ROUTE_ENC)] && $::env(SOC_ROUTE_ENC) ne "" ? [file normalize $::env(SOC_ROUTE_ENC)] : [file join $proj_root pd postroute_pg_reconnect_blockpin_20260409 with_sram_probe.enc.dat]}]
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

proc boxes_intersect {a b} {
    lassign $a allx ally aurx aury
    lassign $b bllx blly burx bury
    if {$aurx < $bllx || $burx < $allx} { return 0 }
    if {$aury < $blly || $bury < $ally} { return 0 }
    return 1
}

proc collect_swire_objs {net_name layer area} {
    set objs {}
    set net_ptr [dbGet top.nets.name $net_name -p]
    foreach sw [dbGet $net_ptr.sWires] {
        set sw_layer [dbGet $sw.layer.name]
        if {$sw_layer ne $layer} { continue }
        set box [join [dbGet $sw.box]]
        if {[llength $box] != 4} { continue }
        if {![boxes_intersect $box $area]} { continue }
        lappend objs $sw
    }
    return $objs
}

proc add_corner_vias {net_name area} {
    set objs {}
    foreach layer {M9 M10} {
        set objs [concat $objs [collect_swire_objs $net_name $layer $area]]
    }
    puts "CORNER_SELECT net=$net_name area={$area} selected=[llength $objs]"
    if {![llength $objs]} {
        return
    }
    deselectAll
    select_obj $objs
    editPowerVia \
        -bottom_layer M9 \
        -top_layer M10 \
        -selected_wires 1 \
        -exclude_stack_vias 0 \
        -add_vias 1 \
        -orthogonal_only 0 \
        -via_using_exact_crossover_size 1 \
        -skip_via_on_pin {pad cover} \
        -skip_via_on_wire_shape {}
    deselectAll
}

restoreDesign $route_enc soc_top

set pre_drc [file join $pnr_out_dir drc_pre.rpt]
set pre_reg [file join $pnr_out_dir lvs_connectivity_regular_pre.rpt]
set pre_spc [file join $pnr_out_dir lvs_connectivity_special_pre.rpt]
verify_drc -limit 10000 -report $pre_drc
verifyConnectivity -type regular -error 1000 -warning 100 -report $pre_reg
verifyConnectivity -type special -noAntenna -error 2000 -warning 100 -report $pre_spc
puts "FAST_FIX_BASELINE DRC=[parse_drc_violations $pre_drc] REG=[parse_connectivity_errors $pre_reg] SPC=[parse_connectivity_errors $pre_spc]"

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

add_corner_vias VDD {42.800 42.800 45.300 45.300}
add_corner_vias VDD {291.100 291.000 293.700 293.400}
add_corner_vias VSS {38.800 38.800 41.300 41.300}
add_corner_vias VSS {295.100 295.000 297.700 297.400}

set drc_rpt [file join $pnr_out_dir drc_final.rpt]
set reg_rpt [file join $pnr_out_dir lvs_connectivity_regular.rpt]
set spc_rpt [file join $pnr_out_dir lvs_connectivity_special.rpt]

verify_drc -limit 10000 -report $drc_rpt
verifyConnectivity -type regular -error 1000 -warning 100 -report $reg_rpt
verifyConnectivity -type special -noAntenna -error 2000 -warning 100 -report $spc_rpt

saveDesign [file join $pnr_out_dir with_sram_ring_corner_fast.enc]
puts "FAST_FIX_SUMMARY DRC=[parse_drc_violations $drc_rpt] REG=[parse_connectivity_errors $reg_rpt] SPC=[parse_connectivity_errors $spc_rpt]"
exit
