set in_layout "./output/soc_top.dmmerge_boundary_ap_via3onecut.oas.gz"
set out_layout "./output/soc_top.dmmerge_boundary_ap_via3onecut_cts2swap.oas.gz"

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

proc replace_ref {top topCell src dst x y mirror angle mag props} {
    set prop_args [props_to_args $props]
    set del_cmd [concat [list $top delete ref $topCell $src $x $y $mirror $angle $mag] $prop_args]
    set cre_cmd [concat [list $top create ref $topCell $dst $x $y $mirror $angle $mag] $prop_args]
    catch {eval $del_cmd}
    catch {eval $cre_cmd}
}

set top [layout create $in_layout -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
set topCell [$top topcell]

set src "soc_top_NR_VIA3_1x2_VH_HE_M3VIA3M4_2_2_1_17_KEEP_LEFT"
set dst "soc_top_NR_VIA3_1x2_VH_H_M3VIA3M4_2_2_1_5_KEEP_LEFT_M4_OVERLAP"
replace_ref $top $topCell $src $dst 103864 218016 0 0.0 1.0 {{1 u_cordic_accel/u_cordic_ctrl/u_core_atan2/CTS_2}}

$top oasisout $out_layout $topCell
exit
