set in_layout "./output/soc_top.dmmerge_boundary_ap_via3trim_m4overlap.oas.gz"
set out_layout "./output/soc_top.dmmerge_boundary_ap_via3trim_m4en_longcover.oas.gz"

set top [layout create $in_layout -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
set topCell [$top topcell]
catch {$top create layer 34.150}

# Same-net M4 covers for the two single VIA3 enclosure markers. These keep
# the VIA3 refs in place for LVS while making the local M4 enclosure legal.
catch {eval [list $top create polygon $topCell 34.150 -prop 1 {u_cordic_accel/u_cordic_ctrl/u_core_sincos/N3464} 172760 191136 173064 191136 173064 191296 172760 191296]}
catch {eval [list $top create polygon $topCell 34.150 -prop 1 {u_cordic_accel/u_cordic_ctrl/u_core_sincos/FE_PHN9120_N3150} 179480 189776 179784 189776 179784 189936 179480 189936]}

$top oasisout $out_layout $topCell
exit
