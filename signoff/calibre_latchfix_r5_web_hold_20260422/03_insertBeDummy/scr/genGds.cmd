set gdsIn [ glob -nocomplain "*EOL*.gds"]
set inputGds [lindex $gdsIn 0]
set top [layout create $inputGds -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
set TopCell [$top topcell]
set gdsout "./output/soc_top.dmoas.gz"
$top oasisout $gdsout $TopCell
