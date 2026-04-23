set in_layout "./output/soc_top.dmmerge_boundary_ap.oas.gz"
set out_layout "./output/soc_top.dmmerge_boundary_ap_via3onecut.oas.gz"

proc props_to_args {props} {
    set args {}
    foreach prop $props {
        if {[llength $prop] < 2} {
            continue
        }
        lappend args -prop [lindex $prop 0] [lindex $prop 1]
        if {[llength $prop] > 2 && [lindex $prop 2] ne ""} {
            lappend args [lindex $prop 2]
        }
    }
    return $args
}

proc clone_cell {top src dst} {
    catch {$top create cell $dst}
    catch {$top create ref $dst $src 0 0 0 0 1}
    catch {$top flatten ref $dst $src 0 0 0 0 1}
}

proc delete_poly {top cell layer coords} {
    set cmd [concat [list $top delete polygon $cell $layer] $coords]
    catch {eval $cmd}
}

proc create_poly {top cell layer coords} {
    set cmd [concat [list $top create polygon $cell $layer] $coords]
    catch {eval $cmd}
}

proc replace_ref {top topCell src dst x y mirror angle mag props} {
    set prop_args [props_to_args $props]
    set del_cmd [concat [list $top delete ref $topCell $src $x $y $mirror $angle $mag] $prop_args]
    set cre_cmd [concat [list $top create ref $topCell $dst $x $y $mirror $angle $mag] $prop_args]
    catch {eval $del_cmd}
    catch {eval $cre_cmd}
}

set top [layout create $in_layout -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
set topCell [$top topcell]

foreach layer {34.150 53.150} {
    catch {$top create layer $layer}
}

set via3_h_src "soc_top_NR_VIA3_1x2_VH_H_M3VIA3M4_2_2_1_5"
set via3_h_keep_right "${via3_h_src}_KEEP_RIGHT_M4_OVERLAP"
set via3_h_keep_left "${via3_h_src}_KEEP_LEFT_M4_OVERLAP"

clone_cell $top $via3_h_src $via3_h_keep_right
delete_poly $top $via3_h_keep_right 53.150 {-66 -16 -34 -16 -34 16 -66 16}
delete_poly $top $via3_h_keep_right 34.150 {-101 -20 101 -20 101 20 -101 20}
create_poly $top $via3_h_keep_right 34.150 {-20 -20 101 -20 101 20 -20 20}

clone_cell $top $via3_h_src $via3_h_keep_left
delete_poly $top $via3_h_keep_left 53.150 {34 -16 66 -16 66 16 34 16}
delete_poly $top $via3_h_keep_left 34.150 {-101 -20 101 -20 101 20 -101 20}
create_poly $top $via3_h_keep_left 34.150 {-101 -20 20 -20 20 20 -101 20}

set via3_he_src "soc_top_NR_VIA3_1x2_VH_HE_M3VIA3M4_2_2_1_17"
set via3_he_keep_left "${via3_he_src}_KEEP_LEFT"
clone_cell $top $via3_he_src $via3_he_keep_left
delete_poly $top $via3_he_keep_left 53.150 {34 -16 66 -16 66 16 34 16}

replace_ref $top $topCell $via3_he_src $via3_he_keep_left 103864 218016 0 0.0 1.0 {{1 u_cordic_accel/u_cordic_ctrl/u_core_atan2/CTS_2}}
replace_ref $top $topCell $via3_h_src $via3_h_keep_right 118290 206336 0 0.0 1.0 {{1 u_cordic_accel/u_cordic_ctrl/u_core_atan2/N1717}}
replace_ref $top $topCell $via3_h_src $via3_h_keep_right 118740 228096 0 0.0 1.0 {{1 u_cordic_accel/u_cordic_ctrl/u_core_atan2/N2575}}
replace_ref $top $topCell $via3_h_src $via3_h_keep_right 144184 218256 0 0.0 1.0 {{1 u_cordic_accel/u_cordic_ctrl/u_core_atan2/N1467}}
replace_ref $top $topCell $via3_h_src $via3_h_keep_left 192540 141776 0 0.0 1.0 {{1 u_cordic_accel/u_cordic_ctrl/u_core_sincos/N4062}}
replace_ref $top $topCell $via3_h_src $via3_h_keep_left 164472 76576 0 0.0 1.0 {{1 u_cpu/FE_DBTN21_n148}}

$top oasisout $out_layout $topCell
exit
