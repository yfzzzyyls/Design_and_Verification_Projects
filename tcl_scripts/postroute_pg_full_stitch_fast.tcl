set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd postroute_pg_full_stitch_fast]}]
set route_enc [expr {[info exists ::env(SOC_ROUTE_ENC)] && $::env(SOC_ROUTE_ENC) ne "" ? [file normalize $::env(SOC_ROUTE_ENC)] : [file join $proj_root pd innovus_axi_uartcordic_rowmesh_nom1c_20260411_201037 with_sram_route.enc.dat]}]
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

proc parse_connectivity_total {rpt} {
    if {![file exists $rpt]} { return -1 }
    set content [read_text_file $rpt]
    if {[regexp -nocase {Found\s+no\s+problems\s+or\s+warnings\.} $content]} { return 0 }
    set total 0
    foreach line [split $content "\n"] {
        if {[regexp {^\s*([0-9]+)\s+Problem\(s\)} $line -> num]} {
            incr total $num
        }
    }
    return $total
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

restoreDesign $route_enc soc_top
soc_refresh_pg_connectivity

set pre_drc [file join $pnr_out_dir drc_pre.rpt]
set pre_reg [file join $pnr_out_dir lvs_connectivity_regular_pre.rpt]
set pre_spc [file join $pnr_out_dir lvs_connectivity_special_pre.rpt]
verify_drc -limit 10000 -report $pre_drc
verifyConnectivity -type regular -error 1000 -warning 100 -report $pre_reg
verifyConnectivity -type special -noAntenna -error 2000 -warning 100 -report $pre_spc
puts "PG_FULL_STITCH_BASELINE DRC=[parse_drc_violations $pre_drc] REG=[parse_connectivity_total $pre_reg] SPC=[parse_connectivity_total $pre_spc]"

setSrouteMode -viaConnectToShape {ring stripe}
sroute -nets {VDD VSS} -connect {floatingStripe} \
    -floatingStripeTarget {stripe ring} \
    -layerChangeRange {M1 M10} \
    -targetViaLayerRange {M1 M10} \
    -allowLayerChange 1 \
    -allowJogging 1

sroute -nets {VDD VSS} -connect {corePin blockPin} \
    -corePinTarget {ring stripe} \
    -blockPinTarget {ring stripe} \
    -layerChangeRange {M1 M10} \
    -targetViaLayerRange {M1 M10} \
    -allowLayerChange 1 \
    -allowJogging 1

set drc_rpt [file join $pnr_out_dir drc_final.rpt]
set reg_rpt [file join $pnr_out_dir lvs_connectivity_regular.rpt]
set spc_rpt [file join $pnr_out_dir lvs_connectivity_special.rpt]
verify_drc -limit 10000 -report $drc_rpt
verifyConnectivity -type regular -error 1000 -warning 100 -report $reg_rpt
verifyConnectivity -type special -noAntenna -error 2000 -warning 100 -report $spc_rpt

saveDesign [file join $pnr_out_dir with_sram_pg_full_stitch.enc]
puts "PG_FULL_STITCH_SUMMARY DRC=[parse_drc_violations $drc_rpt] REG=[parse_connectivity_total $reg_rpt] SPC=[parse_connectivity_total $spc_rpt]"
exit
