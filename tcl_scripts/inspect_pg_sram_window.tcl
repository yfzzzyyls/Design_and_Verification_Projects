set enc_path [expr {[info exists ::env(SOC_ROUTE_ENC)] && $::env(SOC_ROUTE_ENC) ne "" ? [file normalize $::env(SOC_ROUTE_ENC)] : ""}]
if {$enc_path eq ""} {
    puts "ERROR: SOC_ROUTE_ENC is required"
    exit 2
}

proc boxes_intersect {a b} {
    lassign $a allx ally aurx aury
    lassign $b bllx blly burx bury
    if {$aurx < $bllx || $burx < $allx} { return 0 }
    if {$aury < $blly || $bury < $ally} { return 0 }
    return 1
}

proc collect_boxes {net_name layers area} {
    set out {}
    set net_ptr [dbGet top.nets.name $net_name -p]
    foreach sw [dbGet $net_ptr.sWires] {
        set sw_layer [dbGet $sw.layer.name]
        if {[lsearch -exact $layers $sw_layer] < 0} { continue }
        set box [join [dbGet $sw.box]]
        if {[llength $box] != 4} { continue }
        if {![boxes_intersect $box $area]} { continue }
        lappend out [list $sw_layer $box]
    }
    return $out
}

restoreDesign $enc_path soc_top

set sram_inst [dbGet top.insts.name u_sram/u_sram_macro -p]
set sram_box [expr {$sram_inst eq "" ? "" : [join [dbGet $sram_inst.box]]}]
puts "ENC=$enc_path"
puts "SRAM_BOX=$sram_box"

set main_area {60.0 55.0 106.5 175.0}
set bridge_area {60.0 55.0 106.5 70.0}
set upper_area {60.0 160.0 106.5 175.0}
set layers {M4 M5 M6 M7 M8 M9 M10}

foreach {area_name area_val} [list \
    MAIN $main_area \
    BRIDGE $bridge_area \
    UPPER $upper_area \
] {
    puts "AREA $area_name $area_val"
    foreach net {VDD VSS} {
        set hits [collect_boxes $net $layers $area_val]
        puts "NET $net COUNT [llength $hits]"
        foreach item $hits {
            lassign $item layer box
            puts "  $net $layer $box"
        }
    }
}

exit
