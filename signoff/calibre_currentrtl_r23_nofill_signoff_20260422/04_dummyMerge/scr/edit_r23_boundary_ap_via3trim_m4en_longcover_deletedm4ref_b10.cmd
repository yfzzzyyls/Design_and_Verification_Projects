set in_layout "./output/soc_top.dmmerge_boundary_ap_via3trim_m4en_longcover.oas.gz"
set out_layout "./output/soc_top.dmmerge_boundary_ap_via3trim_m4en_longcover_deletedm4ref_b10.oas.gz"

set top [layout create $in_layout -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]

# The offending dummy M4 cell is inside the dummy-merge wrapper B10asoc_top.
catch {$top delete ref B10asoc_top B10aDM4ORH 179244 189656 0 0.0 1.0}

$top oasisout $out_layout soc_top
exit
