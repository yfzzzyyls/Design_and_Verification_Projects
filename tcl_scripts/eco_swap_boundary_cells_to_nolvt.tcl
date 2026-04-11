set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]

set base_enc   [expr {[info exists ::env(SOC_BASE_ENC)] && $::env(SOC_BASE_ENC) ne "" ? [file normalize $::env(SOC_BASE_ENC)] : [file join $proj_root pd innovus_16boundary_lightfinal_20260410 with_sram_final.enc.dat]}]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd innovus_16boundary_nolvt_20260410]}]
file mkdir $pnr_out_dir

proc read_text_file {path} {
    set fp [open $path r]
    set data [read $fp]
    close $fp
    return $data
}

proc parse_drc_violations {rpt} {
    if {![file exists $rpt]} { return -1 }
    set content [read_text_file $rpt]
    if {[regexp -nocase {No\s+DRC\s+violations\s+were\s+found} $content]} { return 0 }
    if {[regexp -nocase {No\s+violations\s+were\s+found} $content]} { return 0 }
    if {[regexp {Total\s+Violations\s*:\s*([0-9]+)} $content -> num]} { return $num }
    return -1
}

proc parse_connectivity_errors {rpt} {
    if {![file exists $rpt]} { return -1 }
    set content [read_text_file $rpt]
    if {[regexp -nocase {Found\s+no\s+problems\s+or\s+warnings\.} $content]} { return 0 }
    set total 0
    foreach line [split $content "\n"] {
        if {[regexp {^\s*([0-9]+)\s+Problem\(s\)} $line -> num]} {
            incr total $num
        }
    }
    if {$total > 0} { return $total }
    if {[regexp -nocase {Total\s+(Regular|Special)\s+Net\s+Errors\s*:\s*([0-9]+)} $content -> _ num]} { return $num }
    return -1
}

proc parse_antenna_violations {rpt} {
    if {![file exists $rpt]} { return -1 }
    set content [read_text_file $rpt]
    if {[regexp -nocase {No\s+Violations\s+Found} $content]} { return 0 }
    if {[regexp -nocase {Verification\s+Complete\s*:\s*([0-9]+)\s+Violations} $content -> num]} { return $num }
    if {[regexp -nocase {Total\s+number\s+of\s+process\s+antenna\s+violations\s*=\s*([0-9]+)} $content -> num]} { return $num }
    return -1
}

proc soc_refresh_pg_connectivity {} {
    globalNetConnect VDD -type pgpin -pin VDD -all -override
    globalNetConnect VDD -type pgpin -pin VDDM -all -override
    globalNetConnect VDD -type pgpin -pin VPP -all -override
    globalNetConnect VSS -type pgpin -pin VSS -all -override
    globalNetConnect VSS -type pgpin -pin VBB -all -override
    globalNetConnect VDD -type tiehi -all -override
    globalNetConnect VSS -type tielo -all -override
}

proc soc_repair_pg_routes {} {
    setNanoRouteMode -routeAllowPowerGroundPin true
    catch {
        sroute -nets {VDD VSS} -connect {corePin floatingStripe} \
            -corePinTarget {ring stripe} \
            -floatingStripeTarget {stripe ring} \
            -layerChangeRange {M1 M10} \
            -targetViaLayerRange {M1 M10} \
            -allowLayerChange 1 \
            -allowJogging 1
    }
    catch {setPGPinUseSignalRoute TAPCELL*:VPP BOUNDARY_*TAP*:VPP}
    catch {routePGPinUseSignalRoute -maxFanout 1}
}

restoreDesign $base_enc soc_top
catch {setEcoMode -LEQCheck false -honorFixedStatus false -refinePlace false -updateTiming false -batchMode true}

set swap_map {
    BOUNDARY_LEFTBWP16P90LVT BOUNDARY_LEFTBWP16P90
    BOUNDARY_RIGHTBWP16P90LVT BOUNDARY_RIGHTBWP16P90
    BOUNDARY_PCORNERBWP16P90LVT BOUNDARY_PCORNERBWP16P90
    BOUNDARY_NCORNERBWP16P90LVT BOUNDARY_NCORNERBWP16P90
    BOUNDARY_PROW1BWP16P90LVT BOUNDARY_PROW1BWP16P90
    BOUNDARY_PROW2BWP16P90LVT BOUNDARY_PROW2BWP16P90
    BOUNDARY_PROW3BWP16P90LVT BOUNDARY_PROW3BWP16P90
    BOUNDARY_PROW4BWP16P90LVT BOUNDARY_PROW4BWP16P90
    BOUNDARY_NROW1BWP16P90LVT BOUNDARY_NROW1BWP16P90
    BOUNDARY_NROW2BWP16P90LVT BOUNDARY_NROW2BWP16P90
    BOUNDARY_NROW3BWP16P90LVT BOUNDARY_NROW3BWP16P90
    BOUNDARY_NROW4BWP16P90LVT BOUNDARY_NROW4BWP16P90
    BOUNDARY_NTAPBWP16P90LVT_VPP_VSS BOUNDARY_NTAPBWP16P90_VPP_VSS
    BOUNDARY_PTAPBWP16P90LVT_VPP_VSS BOUNDARY_PTAPBWP16P90_VPP_VSS
    BOUNDARY_NTAPBWP16P90LVT BOUNDARY_NTAPBWP16P90
    BOUNDARY_PTAPBWP16P90LVT BOUNDARY_PTAPBWP16P90
    TAPCELLBWP16P90LVT TAPCELLBWP16P90
    TAPCELLBWP16P90LVT_VPP_VSS TAPCELLBWP16P90_VPP_VSS
    TAPCELLBWP16P90LVT_VPP_VBB TAPCELLBWP16P90_VPP_VBB
    BOUNDARY_NTAPBWP20P90LVT BOUNDARY_NTAPBWP20P90
    BOUNDARY_PTAPBWP20P90LVT BOUNDARY_PTAPBWP20P90
    BOUNDARY_NTAPBWP20P90LVT_VPP_VSS BOUNDARY_NTAPBWP20P90_VPP_VSS
    BOUNDARY_PTAPBWP20P90LVT_VPP_VSS BOUNDARY_PTAPBWP20P90_VPP_VSS
    TAPCELLBWP20P90LVT TAPCELLBWP20P90
    TAPCELLBWP20P90LVT_VPP_VSS TAPCELLBWP20P90_VPP_VSS
    TAPCELLBWP20P90LVT_VPP_VBB TAPCELLBWP20P90_VPP_VBB
}

foreach {old_cell new_cell} $swap_map {
    set inst_ptrs [dbGet -u -e [dbGet -p2 top.insts.cell.name $old_cell]]
    set insts [dbGet -u -e $inst_ptrs.name]
    if {[llength $insts] == 0} {
        continue
    }
    puts "Swapping [llength $insts] instances: $old_cell -> $new_cell"
    ecoChangeCell -inst $insts -cell $new_cell
}
catch {setEcoMode -batchMode false}

soc_refresh_pg_connectivity
soc_repair_pg_routes

set max_eco_iters 3
set eco_iter 0
set drc_rpt [file join $pnr_out_dir drc_with_sram_iter0.rpt]
verify_drc -limit 10000 -report $drc_rpt
set drc_viol [parse_drc_violations $drc_rpt]
while {$drc_viol > 0 && $eco_iter < $max_eco_iters} {
    incr eco_iter
    catch {ecoRoute -fix_drc}
    set drc_rpt [file join $pnr_out_dir drc_with_sram_iter${eco_iter}.rpt]
    verify_drc -limit 10000 -report $drc_rpt
    set drc_viol [parse_drc_violations $drc_rpt]
}

set conn_regular_rpt [file join $pnr_out_dir lvs_connectivity_regular.rpt]
set conn_special_rpt [file join $pnr_out_dir lvs_connectivity_special.rpt]
verifyConnectivity -type regular -error 1000 -warning 100 -report $conn_regular_rpt
verifyConnectivity -type special -noAntenna -error 1000 -warning 100 -report $conn_special_rpt

set antenna_rpt [file join $pnr_out_dir lvs_process_antenna.rpt]
catch {verifyProcessAntenna -report $antenna_rpt}

saveDesign [file join $pnr_out_dir with_sram_final.enc]
puts "BOUNDARY_SWAP_SUMMARY DRC=[parse_drc_violations $drc_rpt] REG=[parse_connectivity_errors $conn_regular_rpt] SPC=[parse_connectivity_errors $conn_special_rpt] ANT=[parse_antenna_violations $antenna_rpt]"
exit
