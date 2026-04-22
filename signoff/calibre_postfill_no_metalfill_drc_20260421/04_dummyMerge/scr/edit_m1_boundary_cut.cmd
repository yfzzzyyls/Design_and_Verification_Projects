set in_layout "./output/soc_top.dmmerge.oas.gz"
set out_layout "./output/soc_top.dmmerge_m1boundarycut.oas.gz"

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
    set cmd [concat $args $coords]
    catch {eval $cmd}
}

set top [layout create $in_layout -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
set topCell [$top topcell]

set src_cell "BOUNDARY_LEFTBWP16P90"
set fix_cell "${src_cell}_M1_CUT"

clone_cell $top $src_cell $fix_cell

# Same local M1 edge shapes that the reference clean flow removes from the
# BOUNDARY_LEFT variant near the SRAM macro edge.
delete_poly $top $fix_cell {31 -53 -45 413 -45 413 45 -53 45}
delete_poly $top $fix_cell {31 -53 531 413 531 413 621 -53 621}

set die_llx 0
set die_lly 0
set die_urx 338850
set die_ury 338496

set macro_lly 62016
set macro_urx 105065
set macro_ury 167568
set edge_window 1000

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

    if {$refcell ne $src_cell} {
        continue
    }

    set bbox_ury [expr {$bbox_y + $bbox_h}]
    if {!($bbox_y < $macro_ury && $bbox_ury > $macro_lly)} {
        continue
    }
    set bbox_urx [expr {$bbox_x + [lindex $ref 2]}]
    if {!($bbox_x <= $macro_urx && $bbox_urx >= $macro_urx)} {
        continue
    }

    set prop_args [props_to_args $props]
    set delete_cmd [concat [list $top delete ref $topCell $src_cell $x $y $mirror $angle $mag] $prop_args]
    set create_cmd [concat [list $top create ref $topCell $fix_cell $x $y $mirror $angle $mag] $prop_args]
    set flatten_cmd [concat [list $top flatten ref $topCell $fix_cell $x $y $mirror $angle $mag] $prop_args]
    set delete_fix_cmd [concat [list $top delete ref $topCell $fix_cell $x $y $mirror $angle $mag] $prop_args]
    catch {eval $delete_cmd}
    catch {eval $create_cmd}
    catch {eval $flatten_cmd}
    catch {eval $delete_fix_cmd}
    incr swap_count
}

puts "Swapped $swap_count $src_cell refs near SRAM edge"
$top oasisout $out_layout $topCell
exit
