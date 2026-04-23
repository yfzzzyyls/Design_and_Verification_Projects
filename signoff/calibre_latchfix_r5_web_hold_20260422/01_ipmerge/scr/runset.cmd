set raw [layout create "/home/fy2243/soc_design/signoff/calibre_latchfix_r5_web_hold_20260422/00_export/soc_top.oas.gz" -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
set top [layout create "/home/fy2243/soc_design/signoff/calibre_latchfix_r5_web_hold_20260422/00_export/soc_top.oas.gz" -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
set TopCell [$top topcell]
set usedCells [$raw cells]
if {"full" eq "used_nonphysical"} {
    foreach gdsFile [list "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/GDS/N16ADFP_StdCell.gds" "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/IP/sram/N16ADFP_SRAM/GDS/N16ADFP_SRAM_100a.gds"] {
        puts "import $gdsFile"
        $top import layout "$gdsFile" FALSE overwrite -dt_expand -preservePaths -preserveTextAttributes -preserveProperties
    }
    set physRegex {^(BOUNDARY_|FILL|DCAP|DECAP|TAPCELL|PCORNER|PFILLER|PVDD)}
    foreach cellName $usedCells {
        if {![regexp $physRegex $cellName]} {
            continue
        }
        puts "restore physical $cellName"
        set restoreLayers [lsort -unique [concat [$top layers -cell $cellName] [$raw layers -cell $cellName]]]
        foreach layer $restoreLayers {
            $top delete objects $cellName $layer
        }
        foreach layer [$raw layers -cell $cellName] {
            $top COPYCELL GEOM $raw $cellName $layer $cellName $layer
        }
    }
} else {
    foreach gdsFile [list "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/GDS/N16ADFP_StdCell.gds" "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/IP/sram/N16ADFP_SRAM/GDS/N16ADFP_SRAM_100a.gds"] {
        set toImport [layout create "$gdsFile" -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
        puts "import $gdsFile"
        $top import layout $toImport FALSE overwrite -dt_expand -preservePaths -preserveTextAttributes -preserveProperties
    }
}
$top create layer 108.250
$top create polygon soc_top 108.250 0 0 338.310000u 337.344000u
$top oasisout ./output/soc_top.oas.gz $TopCell
