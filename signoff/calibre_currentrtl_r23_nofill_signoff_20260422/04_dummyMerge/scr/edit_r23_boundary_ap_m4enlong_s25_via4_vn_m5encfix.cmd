set in_layout "./output/soc_top.dmmerge_boundary_ap_via3trim_m4en_longcover_deletedm4ref_b10.oas.gz"
set out_layout "./output/soc_top.dmmerge_boundary_ap_m4enlong_s25_via4_vn_m5encfix.oas.gz"

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

proc delete_poly_simple {top cell layer coords} {
    set cmd [concat [list $top delete polygon $cell $layer] $coords]
    catch {eval $cmd}
}

proc create_poly_simple {top cell layer coords} {
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

set via4_src "soc_top_NR_VIA4_2x1_HV_V_M4VIA4M5_2_1_2_18"
set via4_vn "soc_top_NR_VIA4_2x1_HV_VN_M4VIA4M5_2_1_2_35"

# Move the upper VIA4 cuts north at the two remaining M4.S.25 hotspots.
replace_ref $top $topCell $via4_src $via4_vn 176520 65696 0 0.0 1.0 {{1 u_cpu/n155}}
replace_ref $top $topCell $via4_src $via4_vn 184600 76336 0 0.0 1.0 {{1 u_cpu/FE_PHN4818_n4173}}

# Remove the old south-reaching M4 cover polygons; the VN via master carries
# the landing north of the spacing hotspot.
delete_poly $top $topCell {34.150 {{1 u_cpu/n155}} 176440 65580 176600 65580 176600 65804 176440 65804}
delete_poly $top $topCell {34.150 {{1 u_cpu/n155}} 176440 65600 176720 65600 176720 65804 176440 65804}
delete_poly $top $topCell {34.150 {{1 u_cpu/FE_PHN4818_n4173}} 184520 76220 184680 76220 184680 76444 184520 76444}
delete_poly $top $topCell {34.150 {{1 u_cpu/FE_PHN4818_n4173}} 184520 76240 184800 76240 184800 76444 184520 76444}

set via4_m5encfix "${via4_vn}_M5ENCFIX"
clone_cell $top $via4_vn $via4_m5encfix

# Keep one VIA4 cut at the second hotspot and resize M5 to satisfy enclosure
# while staying away from the neighboring M5 net above.
delete_poly_simple $top $via4_m5encfix 54.240 {-20 126 20 126 20 166 -20 166}
delete_poly_simple $top $via4_m5encfix 35.245 {-20 -40 20 -40 20 216 -20 216}
create_poly_simple $top $via4_m5encfix 35.245 {-20 -40 20 -40 20 100 -20 100}

replace_ref $top $topCell $via4_vn $via4_m5encfix 184600 76336 0 0.0 1.0 {{1 u_cpu/FE_PHN4818_n4173}}

$top oasisout $out_layout $topCell
exit
