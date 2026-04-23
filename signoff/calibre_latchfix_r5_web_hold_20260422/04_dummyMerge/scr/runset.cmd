set top [layout create "../01_ipmerge/output/soc_top.oas.gz" -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
foreach gdsFile [list "../03_insertBeDummy/output/soc_top.dmoas.gz" "../02_insertFeDummy/output/soc_top.dodoas.gz"] {
    set toImport [layout create "$gdsFile" -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
    set checkTopCell [$toImport topcell]
    if {$checkTopCell == ""} {
        puts "skip $gdsFile due to 0 cell gds"
    } else {
        set gdsRename [$toImport topcell]
        $top import layout $toImport FALSE overwrite -dt_expand -preservePaths -preserveTextAttributes -preserveProperties
        $top create ref soc_top $gdsRename 0 0 0 0 1
    }
}
$top oasisout ./output/soc_top.dmmerge.oas.gz soc_top
