set in_layout "./output/soc_top.dmmerge_boundary_ap.oas.gz"
set out_layout "./output/soc_top.dmmerge_boundary_ap_via3trim_m4overlap.oas.gz"

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

# Vertical 2-cut VIA3: remove the lower cut, keep the upper cut, and keep
# enough M4 overlap to merge with the existing route path.
set via3_v_src "soc_top_NR_VIA3_2x1_VH_V_M3VIA3M4_2_1_2_5"
set via3_v_top "${via3_v_src}_KEEP_TOP_M4_OVERLAP"
clone_cell $top $via3_v_src $via3_v_top
delete_poly $top $via3_v_top 53.150 {-16 -66 16 -66 16 -34 -16 -34}
delete_poly $top $via3_v_top 34.150 {-60 -96 60 -96 60 96 -60 96}
create_poly $top $via3_v_top 34.150 {-60 -20 60 -20 60 96 -60 96}

# Horizontal 2-cut VIA3: remove the left cut, keep the right cut, and keep
# enough M4 overlap to merge with the existing route path.
set via3_h_src "soc_top_NR_VIA3_1x2_VH_H_M3VIA3M4_2_2_1_4"
set via3_h_right "${via3_h_src}_KEEP_RIGHT_M4_OVERLAP"
clone_cell $top $via3_h_src $via3_h_right
delete_poly $top $via3_h_right 53.150 {-66 -16 -34 -16 -34 16 -66 16}
delete_poly $top $via3_h_right 34.150 {-101 -20 101 -20 101 20 -101 20}
create_poly $top $via3_h_right 34.150 {-20 -20 101 -20 101 20 -20 20}

replace_ref $top $topCell $via3_v_src $via3_v_top 120184 248016 0 0.0 1.0 {{1 u_cordic_accel/u_cordic_ctrl/u_core_atan2/FE_PHN4275_DP_OP_97J2_191_5360_n2}}
replace_ref $top $topCell $via3_h_src $via3_h_right 147320 180416 0 0.0 1.0 {{1 u_cordic_accel/u_cordic_ctrl/u_core_sincos/N4368}}
replace_ref $top $topCell $via3_v_src $via3_v_top 151864 250176 0 0.0 1.0 {{1 u_cordic_accel/u_cordic_ctrl/u_core_atan2/FE_PHN3259_y_pipe_11__10}}
replace_ref $top $topCell $via3_v_src $via3_v_top 174456 123696 0 0.0 1.0 {{1 u_cpu/n3669}}

$top oasisout $out_layout $topCell
exit
