set in_layout "./output/soc_top.dmmerge_m1boundarycut_ap.oas.gz"
set out_layout "./output/soc_top.dmmerge_m1boundarycut_ap_via3.oas.gz"

proc props_to_args {props} {
    set args {}
    foreach prop $props {
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
    set cmd [concat [list $top delete polygon $cell [lindex $poly 0]] [lrange $poly 1 end]]
    catch {eval $cmd}
}

proc ref_cmd {op top cell spec} {
    set cmd [concat [list $top $op ref $cell] $spec]
    catch {eval $cmd}
}

set top [layout create $in_layout -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
set topCell [$top topcell]

set h_src "soc_top_NR_VIA3_1x2_VH_H_M3VIA3M4_2_2_1_4"
set h_dst "${h_src}_FIXLEFT"
clone_cell $top $h_src $h_dst
delete_poly $top $h_dst {53.150 -66 -16 -34 -16 -34 16 -66 16}

set hw_src "soc_top_NR_VIA3_1x2_VH_HW_M3VIA3M4_2_2_1_13"
set hw_dst "${hw_src}_FIXLEFT"
clone_cell $top $hw_src $hw_dst
delete_poly $top $hw_dst {53.150 -146 -16 -114 -16 -114 16 -146 16}

set p1 [props_to_args {{1 u_cordic_accel/u_cordic_ctrl/u_core_atan2/N1419}}]
ref_cmd delete $top $topCell [concat [list $h_src 99000 206256 0 0.0 1.0] $p1]
ref_cmd create $top $topCell [concat [list $h_dst 99000 206256 0 0.0 1.0] $p1]

set p2 [props_to_args {{1 u_cordic_accel/u_cordic_ctrl/u_core_sincos/N505}}]
ref_cmd delete $top $topCell [concat [list $hw_src 201528 156816 0 0.0 1.0] $p2]
ref_cmd create $top $topCell [concat [list $hw_dst 201528 156816 0 0.0 1.0] $p2]

puts "Replaced 2 VIA3 refs with left-cut versions"
$top oasisout $out_layout $topCell
exit
