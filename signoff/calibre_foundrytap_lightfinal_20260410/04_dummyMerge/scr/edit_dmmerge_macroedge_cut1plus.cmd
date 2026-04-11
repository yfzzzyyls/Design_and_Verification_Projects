set in_layout "./output/soc_top.dmmerge_stripbase.oas.gz"
set out_layout "./output/soc_top.dmmerge_macroedge_cut1plus.oas.gz"

proc props_to_args {props} {
    set args {}
    foreach prop $props {
        if {[llength $prop] < 2} {
            continue
        }
        set attr [lindex $prop 0]
        set value [lindex $prop 1]
        set scope [lindex $prop 2]
        lappend args -prop $attr $value
        if {$scope ne ""} {
            lappend args $scope
        }
    }
    return $args
}

proc get_prop_value {props attr_name} {
    foreach prop $props {
        if {[llength $prop] < 2} {
            continue
        }
        if {[lindex $prop 0] eq $attr_name} {
            return [lindex $prop 1]
        }
    }
    return ""
}

proc clone_cell {top src dst} {
    catch {$top create cell $dst}
    catch {$top create ref $dst $src 0 0 0 0 1}
    catch {$top flatten ref $dst $src 0 0 0 0 1}
}

proc delete_poly {top cell poly} {
    set layer [lindex $poly 0]
    set args [list $top delete polygon $cell $layer]
    set coords [lrange $poly 1 end]

    if {[llength $poly] > 2} {
        set maybe_props [lindex $poly 1]
        if {[llength $maybe_props] > 0 && [llength [lindex $maybe_props 0]] >= 2} {
            set coords [lrange $poly 2 end]
            foreach prop $maybe_props {
                lappend args -prop [lindex $prop 0] [lindex $prop 1]
                if {[llength $prop] > 2 && [lindex $prop 2] ne ""} {
                    lappend args [lindex $prop 2]
                }
            }
        }
    }

    set cmd [concat $args $coords]
    catch {eval $cmd}
}

proc ref_cmd {op top cell spec} {
    set cmd [concat [list $top $op ref $cell] $spec]
    catch {eval $cmd}
}

set top [layout create $in_layout -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
set topCell [$top topcell]

array set fix_map {
    BOUNDARY_LEFTBWP16P90LVT BOUNDARY_LEFTBWP16P90LVT_DM_CUT1P
    DCAP4BWP16P90            DCAP4BWP16P90_DM_CUT1P
    DCAP8BWP16P90            DCAP8BWP16P90_DM_CUT1P
    DCAP16BWP16P90           DCAP16BWP16P90_DM_CUT1P
    DCAP32BWP16P90           DCAP32BWP16P90_DM_CUT1P
    DCAP64BWP16P90           DCAP64BWP16P90_DM_CUT1P
}

clone_cell $top "BOUNDARY_LEFTBWP16P90LVT" $fix_map(BOUNDARY_LEFTBWP16P90LVT)
delete_poly $top $fix_map(BOUNDARY_LEFTBWP16P90LVT) {31 -53 -45 413 -45 413 45 -53 45}
delete_poly $top $fix_map(BOUNDARY_LEFTBWP16P90LVT) {31 -53 531 413 531 413 621 -53 621}

clone_cell $top "DCAP4BWP16P90" $fix_map(DCAP4BWP16P90)
delete_poly $top $fix_map(DCAP4BWP16P90) {31 -53 531 413 531 413 621 -53 621}

clone_cell $top "DCAP8BWP16P90" $fix_map(DCAP8BWP16P90)
delete_poly $top $fix_map(DCAP8BWP16P90) {31 -53 531 773 531 773 621 -53 621}

clone_cell $top "DCAP16BWP16P90" $fix_map(DCAP16BWP16P90)
delete_poly $top $fix_map(DCAP16BWP16P90) {31 -53 531 1493 531 1493 621 -53 621}

clone_cell $top "DCAP32BWP16P90" $fix_map(DCAP32BWP16P90)
delete_poly $top $fix_map(DCAP32BWP16P90) {31 -53 531 2933 531 2933 621 -53 621}

clone_cell $top "DCAP64BWP16P90" $fix_map(DCAP64BWP16P90)
delete_poly $top $fix_map(DCAP64BWP16P90) {31 -53 531 5813 531 5813 621 -53 621}

set via3_fix_src "soc_top_NR_VIA3_1x2_VH_H_M3VIA3M4_2_2_1_4"
set via3_fix_dst "${via3_fix_src}_FIXLEFT"
clone_cell $top $via3_fix_src $via3_fix_dst
delete_poly $top $via3_fix_dst {53.150 -66 -16 -34 -16 -34 16 -66 16}

array set explicit_props {
    EC_633 1
    EC_637 1
    EC_641 1
    EC_645 1
    EC_649 1
    EC_653 1
    EC_657 1
    EC_661 1
    EC_665 1
    EC_669 1
    EC_673 1
    EC_677 1
    EC_681 1
    EC_685 1
    EC_689 1
    FILLER_T_7_2058 1
    FILLER_T_7_2188 1
    FILLER_T_7_2315 1
}

set die_llx 50000
set die_lly 50000
set die_urx 286200
set die_ury 285700

set macro_lly 62016
set macro_urx 105065
set macro_ury 167568

set refs [$top query ref $topCell 0 3 $die_llx $die_lly $die_urx $die_ury -all -list]
foreach ref $refs {
    if {[llength $ref] < 11} {
        continue
    }

    set bbox_x [lindex $ref 0]
    set bbox_y [lindex $ref 1]
    set bbox_w [lindex $ref 2]
    set bbox_h [lindex $ref 3]
    set refcell [lindex $ref 4]
    set x [lindex $ref 5]
    set y [lindex $ref 6]
    set mirror [lindex $ref 7]
    set angle [lindex $ref 8]
    set mag [lindex $ref 9]
    set props [lindex $ref 10]

    if {![info exists fix_map($refcell)]} {
        continue
    }

    set bbox_urx [expr {$bbox_x + $bbox_w}]
    set bbox_ury [expr {$bbox_y + $bbox_h}]
    set prop_name [get_prop_value $props 1]

    set swap_ref 0
    if {$bbox_y < $macro_ury && $bbox_ury > $macro_lly} {
        if {$refcell eq "BOUNDARY_LEFTBWP16P90LVT"} {
            if {$bbox_x <= $macro_urx && $bbox_urx >= $macro_urx} {
                set swap_ref 1
            }
        } else {
            if {$bbox_x >= $macro_urx && $bbox_x <= ($macro_urx + 2000)} {
                set swap_ref 1
            }
        }
    }
    if {[info exists explicit_props($prop_name)]} {
        set swap_ref 1
    }
    if {!$swap_ref} {
        continue
    }

    set prop_args [props_to_args $props]
    set delete_cmd [concat [list $top delete ref $topCell $refcell $x $y $mirror $angle $mag] $prop_args]
    set create_cmd [concat [list $top create ref $topCell $fix_map($refcell) $x $y $mirror $angle $mag] $prop_args]
    set flatten_cmd [concat [list $top flatten ref $topCell $fix_map($refcell) $x $y $mirror $angle $mag] $prop_args]
    set delete_fix_cmd [concat [list $top delete ref $topCell $fix_map($refcell) $x $y $mirror $angle $mag] $prop_args]
    catch {eval $delete_cmd}
    catch {eval $create_cmd}
    catch {eval $flatten_cmd}
    catch {eval $delete_fix_cmd}
}

# Patch the remaining VIA3 enclosure error by trimming only the offending cut.
set via3_props {{1 u_cordic/u_core_sincos/N1456}}
set via3_prop_args [props_to_args $via3_props]
ref_cmd delete $top $topCell [concat [list $via3_fix_src 152850 183856 0 0.0 1.0] $via3_prop_args]
ref_cmd create $top $topCell [concat [list $via3_fix_dst 152850 183856 0 0.0 1.0] $via3_prop_args]

# Patch the residual M4 rule markers in top-level space.
foreach layer {33.70 34.150 53.150 74.0} {
    catch {$top create layer $layer}
}

delete_poly $top $topCell {34.150 {{1 VDD}} 105227 61313 105317 61313 105317 61758 105227 61758}
delete_poly $top $topCell {34.150 {{1 VDD}} 105291 61313 105381 61313 105381 61758 105291 61758}
delete_poly $top $topCell {34.150 {{1 VDD}} 98240 61491 105272 61491 105272 61581 98240 61581}
delete_poly $top $topCell {34.150 {{1 VDD}} 98240 61491 105336 61491 105336 61581 98240 61581}
delete_poly $top $topCell {34.150 {{1 VDD}} 98240 61491 105416 61491 105416 61581 98240 61581}
delete_poly $top $topCell {34.150 206600 64340 206716 64480 206716 64492 206600 64352}
delete_poly $top $topCell {34.150 206600 64352 206716 64352 206716 64480 206600 64480}
delete_poly $top $topCell {53.150 152784 183840 152816 183840 152816 183872 152784 183872}

catch {eval [list $top create polygon $topCell 34.150 -prop 1 VDD 104945 64704 105049 64704 105049 64845 104945 64845]}
catch {eval [list $top create polygon $topCell 34.150 -prop 1 {u_cpu/n4052} 206440 64372 206836 64372 206836 64556 206440 64556]}

set ap_step 50000
set ap_size 30000
for {set ap_x 144} {[expr {$ap_x + $ap_size}] <= 336132} {incr ap_x $ap_step} {
    for {set ap_y 144} {[expr {$ap_y + $ap_size}] <= 335903} {incr ap_y $ap_step} {
        set ap_x2 [expr {$ap_x + $ap_size}]
        set ap_y2 [expr {$ap_y + $ap_size}]
        catch {eval [list $top create polygon $topCell 74.0 $ap_x $ap_y $ap_x2 $ap_y $ap_x2 $ap_y2 $ap_x $ap_y2]}
    }
}

$top oasisout $out_layout $topCell
exit
