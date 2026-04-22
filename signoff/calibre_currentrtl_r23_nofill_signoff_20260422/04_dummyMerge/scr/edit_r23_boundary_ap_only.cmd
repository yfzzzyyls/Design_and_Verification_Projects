set in_layout "./output/soc_top.dmmerge.oas.gz"
set out_layout "./output/soc_top.dmmerge_boundary_ap.oas.gz"

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

set boundary_src "BOUNDARY_LEFTBWP16P90"
set boundary_fix "${boundary_src}_M1_CUT"
clone_cell $top $boundary_src $boundary_fix
delete_poly $top $boundary_fix {31 -53 -45 413 -45 413 45 -53 45}
delete_poly $top $boundary_fix {31 -53 531 413 531 413 621 -53 621}

set die_llx 0
set die_lly 0
set die_urx 338850
set die_ury 338496

set macro_lly 62016
set macro_urx 105065
set macro_ury 167568

set swap_count 0
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

    if {$refcell ne $boundary_src} {
        continue
    }

    set bbox_urx [expr {$bbox_x + $bbox_w}]
    set bbox_ury [expr {$bbox_y + $bbox_h}]
    if {!($bbox_y < $macro_ury && $bbox_ury > $macro_lly)} {
        continue
    }
    if {!($bbox_x <= $macro_urx && $bbox_urx >= $macro_urx)} {
        continue
    }

    set prop_args [props_to_args $props]
    set delete_cmd [concat [list $top delete ref $topCell $boundary_src $x $y $mirror $angle $mag] $prop_args]
    set create_cmd [concat [list $top create ref $topCell $boundary_fix $x $y $mirror $angle $mag] $prop_args]
    set flatten_cmd [concat [list $top flatten ref $topCell $boundary_fix $x $y $mirror $angle $mag] $prop_args]
    set delete_fix_cmd [concat [list $top delete ref $topCell $boundary_fix $x $y $mirror $angle $mag] $prop_args]
    catch {eval $delete_cmd}
    catch {eval $create_cmd}
    catch {eval $flatten_cmd}
    catch {eval $delete_fix_cmd}
    incr swap_count
}
puts "Swapped $swap_count $boundary_src refs near SRAM edge"

catch {$top create layer 74.0}

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
