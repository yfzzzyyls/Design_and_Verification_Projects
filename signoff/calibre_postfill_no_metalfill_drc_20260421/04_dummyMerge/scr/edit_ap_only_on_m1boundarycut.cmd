set in_layout "./output/soc_top.dmmerge_m1boundarycut.oas.gz"
set out_layout "./output/soc_top.dmmerge_m1boundarycut_ap.oas.gz"

set top [layout create $in_layout -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
set topCell [$top topcell]

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
