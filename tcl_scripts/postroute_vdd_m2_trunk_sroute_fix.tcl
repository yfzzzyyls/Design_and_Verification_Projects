set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd postroute_vdd_m2_trunk_sroute_fix]}]
set route_enc [expr {[info exists ::env(SOC_ROUTE_ENC)] && $::env(SOC_ROUTE_ENC) ne "" ? [file normalize $::env(SOC_ROUTE_ENC)] : [file join $proj_root pd innovus_m8pins_vendorboundary_20260409 with_sram_route.enc.dat]}]
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
    if {[regexp -nocase {Total\s+(Regular|Special)\s+Net\s+Errors\s*:\s*([0-9]+)} $content -> _ num]} { return $num }
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

proc add_vdd_m2_trunk {area} {
    setAddStripeMode -reset
    setAddStripeMode \
        -ignore_DRC 0 \
        -use_fgc 1 \
        -remove_floating_stripe_over_block false \
        -stacked_via_bottom_layer M1 \
        -stacked_via_top_layer M2 \
        -keep_pitch_after_snap false \
        -via_using_exact_crossover_size false \
        -ignore_nondefault_domains true \
        -skip_via_on_pin {Pad Block Cover Standardcell Physicalpin} \
        -stapling_nets_style end_to_end \
        -remove_floating_stapling true

    addStripe \
        -area $area \
        -direction vertical \
        -layer M2 \
        -nets {VDD} \
        -start_offset 0 \
        -width 0.064 \
        -spacing 0 \
        -set_to_set_distance 1000 \
        -skip_via_on_wire_shape {} \
        -snap_wire_center_to_grid Grid \
        -uda VDD_TRUNK_SROUTE_FIX
}

restoreDesign $route_enc soc_top
soc_refresh_pg_connectivity

# Add only two localized M2 trunks at the existing M1 VDD row-edge islands,
# then let sroute attach floating stripes instead of forcing broad power vias.
add_vdd_m2_trunk {49.84 75.20 50.12 286.25}
add_vdd_m2_trunk {286.30 75.20 286.54 286.25}

setSrouteMode -viaConnectToShape {ring stripe}
sroute -nets {VDD} -connect {floatingStripe} \
    -floatingStripeTarget {stripe ring} \
    -layerChangeRange {M1 M10} \
    -targetViaLayerRange {M1 M10} \
    -allowLayerChange 1 \
    -allowJogging 1

set drc_rpt [file join $pnr_out_dir drc_vddtrunksroute.rpt]
set reg_rpt [file join $pnr_out_dir lvs_connectivity_regular_vddtrunksroute.rpt]
set spc_rpt [file join $pnr_out_dir lvs_connectivity_special_vddtrunksroute.rpt]

verify_drc -limit 10000 -report $drc_rpt
verifyConnectivity -type regular -error 1000 -warning 100 -report $reg_rpt
verifyConnectivity -type special -noAntenna -error 1000 -warning 100 -report $spc_rpt

saveDesign [file join $pnr_out_dir with_sram_vddtrunksroute.enc]

puts "VDD trunk sroute repair summary:"
puts "  DRC     : [parse_drc_violations $drc_rpt]"
puts "  regular : [parse_connectivity_errors $reg_rpt]"
puts "  special : [parse_connectivity_errors $spc_rpt]"
puts "  saved   : [file join $pnr_out_dir with_sram_vddtrunksroute.enc]"

exit
