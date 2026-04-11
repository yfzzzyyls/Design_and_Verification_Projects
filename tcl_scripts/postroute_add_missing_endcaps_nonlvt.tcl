set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]

set base_enc [expr {[info exists ::env(SOC_BASE_ENC)] && $::env(SOC_BASE_ENC) ne "" ? [file normalize $::env(SOC_BASE_ENC)] : [file join $proj_root pd innovus_16boundary_nolvt_tapswap_20260410 with_sram_final.enc.dat]}]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd innovus_16boundary_endcap_eco_20260410]}]
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
    return $total
}

proc parse_antenna_violations {rpt} {
    if {![file exists $rpt]} { return -1 }
    set content [read_text_file $rpt]
    if {[regexp -nocase {No\s+Violations\s+Found} $content]} { return 0 }
    if {[regexp -nocase {Verification\s+Complete\s*:\s*([0-9]+)\s+Violations} $content -> num]} { return $num }
    return -1
}

restoreDesign $base_enc soc_top

set existing_ecoec [dbGet top.insts.name ECOEC* -e]
if {[llength $existing_ecoec] > 0} {
    deleteInst $existing_ecoec
}

setEndCapMode -reset
setEndCapMode -prefix ECOEC \
    -rightEdge {BOUNDARY_LEFTBWP16P90} \
    -leftEdge {BOUNDARY_RIGHTBWP16P90} \
    -leftTopCorner {BOUNDARY_PCORNERBWP16P90} \
    -leftBottomCorner {BOUNDARY_NCORNERBWP16P90} \
    -topEdge {BOUNDARY_PROW1BWP16P90 BOUNDARY_PROW2BWP16P90 BOUNDARY_PROW3BWP16P90 BOUNDARY_PROW4BWP16P90} \
    -bottomEdge {BOUNDARY_NROW1BWP16P90 BOUNDARY_NROW2BWP16P90 BOUNDARY_NROW3BWP16P90 BOUNDARY_NROW4BWP16P90} \
    -leftTopEdge {FILL3BWP16P90} \
    -leftBottomEdge {FILL3BWP16P90} \
    -rightTopEdge {FILL3BWP16P90} \
    -rightBottomEdge {FILL3BWP16P90} \
    -fitGap true \
    -boundary_tap false
addEndCap -prefix ECOEC

set endcap_rpt [file join $pnr_out_dir verify_endcap.rpt]
set tap_rpt [file join $pnr_out_dir verify_welltap.rpt]
verifyEndCap -report $endcap_rpt

set_well_tap_mode -reset
set_well_tap_mode -insert_cells {{TAPCELLBWP16P90 rule 50.76}}
verifyWellTap -report $tap_rpt

set drc_rpt [file join $pnr_out_dir drc_with_sram_iter0.rpt]
verify_drc -limit 10000 -report $drc_rpt

set conn_regular_rpt [file join $pnr_out_dir lvs_connectivity_regular.rpt]
set conn_special_rpt [file join $pnr_out_dir lvs_connectivity_special.rpt]
verifyConnectivity -type regular -error 1000 -warning 100 -report $conn_regular_rpt
verifyConnectivity -type special -noAntenna -error 1000 -warning 100 -report $conn_special_rpt

set antenna_rpt [file join $pnr_out_dir lvs_process_antenna.rpt]
catch {verifyProcessAntenna -report $antenna_rpt}

saveDesign [file join $pnr_out_dir with_sram_final.enc]
puts "ENDCAP_ECO_SUMMARY DRC=[parse_drc_violations $drc_rpt] REG=[parse_connectivity_errors $conn_regular_rpt] SPC=[parse_connectivity_errors $conn_special_rpt] ANT=[parse_antenna_violations $antenna_rpt]"
exit
