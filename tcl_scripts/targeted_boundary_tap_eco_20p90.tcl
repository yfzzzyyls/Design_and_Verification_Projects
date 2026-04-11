set route_enc [expr {[info exists ::env(SOC_ROUTE_ENC)] && $::env(SOC_ROUTE_ENC) ne "" ? [file normalize $::env(SOC_ROUTE_ENC)] : "/home/fy2243/soc_design/pd/innovus_vendor20boundary_20260409/with_sram_route.enc.dat"}]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : "/home/fy2243/soc_design/pd/innovus_vendor20boundary_tapfix_20260410"}]
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
    if {[regexp {([0-9]+)\s+Problem\(s\)} $content -> num]} { return $num }
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

proc soc_route_boundary_vpp_pgpins {} {
    catch {setPGPinUseSignalRoute TAPCELL*:VPP BOUNDARY_*TAP*:VPP}
    catch {routePGPinUseSignalRoute -maxFanout 1}
}

proc delete_matching_in_box {llx lly urx ury pattern} {
    foreach inst [dbQuery -areas [list [list $llx $lly $urx $ury]] -objType inst] {
        set name [dbGet $inst.name]
        set cell [dbGet $inst.cell.name]
        if {[string match $pattern $cell]} {
            deleteInst $name
        }
    }
}

proc add_fixed_inst {inst_name cell_name x y orient} {
    addInst -cell $cell_name -inst $inst_name -loc [list $x $y] -ori $orient -place_status fixed
}

restoreDesign $route_enc soc_top

# Replace specific bottom/top boundary row fillers with explicit boundary taps.
foreach {inst_name cell_name x y orient delete_pattern} {
    ECO_BOT_TAP_A BOUNDARY_NTAPBWP20P90_VPP_VSS 100.800 50.016 MX BOUNDARY_NROW*
    ECO_BOT_TAP_B BOUNDARY_NTAPBWP20P90_VPP_VSS 202.320 50.016 MX BOUNDARY_NROW*
    ECO_TOP_TAP_A BOUNDARY_NTAPBWP20P90_VPP_VSS 100.800 285.600 R0 BOUNDARY_NROW*
    ECO_TOP_TAP_B BOUNDARY_NTAPBWP20P90_VPP_VSS 202.320 285.600 R0 BOUNDARY_NROW*
} {
    delete_matching_in_box $x $y [expr {$x + 0.90}] [expr {$y + 0.576}] $delete_pattern
    add_fixed_inst $inst_name $cell_name $x $y $orient
}

# Fill the missing bottom regular-tap slot on the right-side strip.
add_fixed_inst ECO_BOT_ROW1_TAP TAPCELLBWP20P90_VPP_VSS 253.080 50.592 R0

soc_refresh_pg_connectivity
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
soc_route_boundary_vpp_pgpins

set max_eco_iters 12
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

set endcap_rpt [file join $pnr_out_dir verify_endcap.rpt]
set tap_rpt [file join $pnr_out_dir verify_welltap.rpt]
verifyEndCap -report $endcap_rpt
verifyWellTap -report $tap_rpt

set conn_regular_rpt [file join $pnr_out_dir lvs_connectivity_regular.rpt]
set conn_special_rpt [file join $pnr_out_dir lvs_connectivity_special.rpt]
verifyConnectivity -type regular -error 1000 -warning 100 -report $conn_regular_rpt
verifyConnectivity -type special -noAntenna -error 1000 -warning 100 -report $conn_special_rpt

set antenna_rpt [file join $pnr_out_dir lvs_process_antenna.rpt]
catch {verifyProcessAntenna -report $antenna_rpt}

saveDesign [file join $pnr_out_dir with_sram_final.enc]
puts "TARGETED_TAP_ECO_20P90_SUMMARY DRC=[parse_drc_violations $drc_rpt] REG=[parse_connectivity_errors $conn_regular_rpt] SPC=[parse_connectivity_errors $conn_special_rpt] ANT=[parse_antenna_violations $antenna_rpt]"
exit
