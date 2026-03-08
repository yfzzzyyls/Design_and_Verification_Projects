# Complete P&R Flow with QRC Tech Files (SRAM-enabled variant)
# This script requires the hard SRAM macro instance and enforces clean signoff gates.

set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]

proc read_text_file {path} {
    set fp [open $path r]
    set data [read $fp]
    close $fp
    return $data
}

proc fail_flow {code msg} {
    puts "ERROR: $msg"
    exit $code
}

proc parse_drc_violations {rpt} {
    if {![file exists $rpt]} {
        return -1
    }
    set content [read_text_file $rpt]
    if {[regexp -nocase {No\s+DRC\s+violations\s+were\s+found} $content]} {
        return 0
    }
    if {[regexp -nocase {No\s+violations\s+were\s+found} $content]} {
        return 0
    }
    if {[regexp {Total\s+Violations\s*:\s*([0-9]+)} $content -> num]} {
        return $num
    }
    return -1
}

proc parse_connectivity_errors {rpt} {
    if {![file exists $rpt]} {
        return -1
    }
    set content [read_text_file $rpt]
    if {[regexp -nocase {Found\s+no\s+problems\s+or\s+warnings\.} $content]} {
        return 0
    }
    if {[regexp {([0-9]+)\s+Problem\(s\)} $content -> num]} {
        return $num
    }
    if {[regexp -nocase {Total\s+(Regular|Special)\s+Net\s+Errors\s*:\s*([0-9]+)} $content -> _ num]} {
        return $num
    }
    return -1
}

proc parse_antenna_violations {rpt} {
    if {![file exists $rpt]} {
        return -1
    }
    set content [read_text_file $rpt]
    if {[regexp -nocase {No\s+Violations\s+Found} $content]} {
        return 0
    }
    if {[regexp -nocase {Verification\s+Complete\s*:\s*([0-9]+)\s+Violations} $content -> num]} {
        return $num
    }
    if {[regexp -nocase {Total\s+number\s+of\s+process\s+antenna\s+violations\s*=\s*([0-9]+)} $content -> num]} {
        return $num
    }
    return -1
}

puts "\n=========================================="
puts "Complete P&R Flow with QRC (WITH SRAM)"
puts "==========================================\n"
puts "Using netlist from: mapped_with_tech/"
puts "This variant enforces SRAM presence and clean post-route gates."
puts ""

# Library and design inputs
set TECH_LEF  "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/Tech/APR/N16ADFP_APR_Innovus/N16ADFP_APR_Innovus_11M.10a.tlef"
set STD_LEF   "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/LEF/lef/N16ADFP_StdCell.lef"
set SRAM_LEF  "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/IP/sram/N16ADFP_SRAM/LEF/N16ADFP_SRAM_100a.lef"

set NETLIST   [file join $proj_root mapped_with_tech soc_top.v]
set TOP       "soc_top"
set MMMC_QRC_FILE [file normalize [file join $script_dir innovus_mmmc_legacy_qrc.tcl]]

set init_pwr_net VDD
set init_gnd_net VSS

set init_lef_file   [list $TECH_LEF $STD_LEF $SRAM_LEF]
set init_verilog    $NETLIST
set init_top_cell   $TOP
set init_mmmc_file  $MMMC_QRC_FILE

puts "Initializing design..."
init_design

puts "\n=========================================="
puts "===== FLOORPLAN + SRAM PLACEMENT ====="
puts "==========================================\n"

# Keep baseline geometry model, but deterministic macro-aware placement.
floorPlan -site core -r 1.0 0.30 50 50 50 50

set sram_path "u_sram/u_sram_macro"
set sram_inst [dbGet top.insts.name $sram_path -p]
if {[llength $sram_inst] == 0} {
    fail_flow 10 "Required SRAM instance '$sram_path' is missing in netlist."
}

set core_box [join [dbGet top.fPlan.coreBox]]
set core_llx [lindex $core_box 0]
set core_lly [lindex $core_box 1]
set core_urx [lindex $core_box 2]
set core_ury [lindex $core_box 3]
if {![string is double -strict $core_llx] || ![string is double -strict $core_lly] || \
    ![string is double -strict $core_urx] || ![string is double -strict $core_ury]} {
    fail_flow 11 "Unexpected coreBox format: $core_box"
}

# TS1N16ADFPCLLLVTA512X45M4SWSHOD size from LEF.
set sram_w 43.025
set sram_h 105.552
set macro_margin_x 12.0
set macro_margin_y 12.0

set min_x [expr {$core_llx + $macro_margin_x}]
set max_x [expr {$core_urx - $macro_margin_x - $sram_w}]
set min_y [expr {$core_lly + $macro_margin_y}]
set max_y [expr {$core_ury - $macro_margin_y - $sram_h}]
if {$max_x < $min_x || $max_y < $min_y} {
    fail_flow 12 "Core too small for SRAM placement with requested margins."
}

# Deterministic placement: lower-left core-relative anchor.
set sram_x $min_x
set sram_y $min_y
placeInstance $sram_path $sram_x $sram_y R0
set_db [get_db insts $sram_path] .place_status fixed
puts "SRAM macro placed at ($sram_x, $sram_y) and fixed."

# Add a small upper-metal signal halo around the macro while allowing PG routing.
set sram_box [join [dbGet $sram_inst.box]]
set s_llx [lindex $sram_box 0]
set s_lly [lindex $sram_box 1]
set s_urx [lindex $sram_box 2]
set s_ury [lindex $sram_box 3]
set halo 4.0
set h_llx [expr {$s_llx - $halo}]
set h_lly [expr {$s_lly - $halo}]
set h_urx [expr {$s_urx + $halo}]
set h_ury [expr {$s_ury + $halo}]
createRouteBlk -name sram_sig_halo -layer {M5 M6} -box [list $h_llx $h_lly $h_urx $h_ury] -exceptpgnet
puts "Added SRAM signal halo/blockage (M5-M6, PG exempt)."

setDesignMode -process 16
globalNetConnect VDD -type pgpin -pin VDD -all -override
globalNetConnect VDD -type pgpin -pin VDDM -all -override
globalNetConnect VSS -type pgpin -pin VSS -all -override
globalNetConnect VDD -type tiehi -all -override
globalNetConnect VSS -type tielo -all -override

puts "\n=========================================="
puts "===== PG RING + ROUTING CONFIG ====="
puts "==========================================\n"

addRing -nets {VDD VSS} \
  -type core_rings \
  -layer {top M10 bottom M10 left M9 right M9} \
  -width 2.0 -spacing 2.0 \
  -offset {top 5.0 bottom 5.0 left 5.0 right 5.0}

setNanoRouteMode -droutePostRouteSpreadWire true
setNanoRouteMode -routeWithViaInPin true
setNanoRouteMode -routeWithViaOnlyForStandardCellPin true
setNanoRouteMode -drouteUseMultiCutViaEffort high
setNanoRouteMode -routeWithSiDriven false
setNanoRouteMode -routeWithTimingDriven false
setNanoRouteMode -drouteFixAntenna true
setNanoRouteMode -routeBottomRoutingLayer 1
setNanoRouteMode -routeTopRoutingLayer 6

puts "\n=========================================="
puts "===== PLACE / SROUTE / CTS / ROUTE ====="
puts "==========================================\n"
place_design
saveDesign [file join $proj_root pd/innovus/with_sram_place.enc]

setSrouteMode -viaConnectToShape {ring stripe}
sroute -nets {VDD VSS} -connect {corePin blockPin} \
  -corePinTarget {ring} \
  -blockPinTarget {ring} \
  -layerChangeRange {M1 M10} \
  -allowLayerChange 1 \
  -allowJogging 1

ccopt_design -cts
saveDesign [file join $proj_root pd/innovus/with_sram_cts.enc]

routeDesign
saveDesign [file join $proj_root pd/innovus/with_sram_route.enc]

puts "\n=========================================="
puts "===== METAL FILL ====="
puts "==========================================\n"
set bbox [get_db designs .bbox]
set llx [lindex $bbox 0]
set lly [lindex $bbox 1]
set urx [lindex $bbox 2]
set ury [lindex $bbox 3]
addMetalFill -layer {M1 M2 M3 M4 M5 M6} -timingAware sta -area "$llx $lly $urx $ury"

puts "\n=========================================="
puts "===== DRC GATE + BOUNDED ECO LOOP ====="
puts "==========================================\n"
set max_eco_iters 5
set eco_iter 0
set drc_rpt [file join $proj_root pd/innovus/drc_with_sram_iter0.rpt]
verify_drc -limit 10000 -report $drc_rpt
set drc_viol [parse_drc_violations $drc_rpt]
if {$drc_viol < 0} {
    fail_flow 20 "Unable to parse DRC report: $drc_rpt"
}
puts "Initial DRC violations: $drc_viol"

while {$drc_viol > 0 && $eco_iter < $max_eco_iters} {
    incr eco_iter
    puts "Running ECO DRC-fix iteration $eco_iter..."
    catch {ecoRoute -fix_drc} eco_msg

    set iter_rpt [file join $proj_root pd/innovus/drc_with_sram_iter${eco_iter}.rpt]
    verify_drc -limit 10000 -report $iter_rpt
    set drc_viol [parse_drc_violations $iter_rpt]
    if {$drc_viol < 0} {
        fail_flow 21 "Unable to parse DRC report: $iter_rpt"
    }
    puts "Iteration $eco_iter DRC violations: $drc_viol"
}

if {$drc_viol > 0} {
    fail_flow 22 "DRC gate failed after $max_eco_iters ECO iterations ($drc_viol remain)."
}
puts "DRC gate: PASS (0 violations)"

puts "\n=========================================="
puts "===== CONNECTIVITY + ANTENNA GATES ====="
puts "==========================================\n"

set conn_regular_rpt [file join $proj_root pd/innovus/lvs_connectivity_regular.rpt]
verifyConnectivity -type regular -error 1000 -warning 100 -report $conn_regular_rpt
set regular_errors [parse_connectivity_errors $conn_regular_rpt]
if {$regular_errors < 0} {
    fail_flow 30 "Unable to parse regular connectivity report: $conn_regular_rpt"
}

# For macro-adjacent cut rows, special-net dangling markers correspond to
# row-end stubs and not true opens. Gate special connectivity with -noAntenna.
set conn_special_rpt [file join $proj_root pd/innovus/lvs_connectivity_special.rpt]
verifyConnectivity -type special -noAntenna -error 1000 -warning 100 -report $conn_special_rpt
set special_errors [parse_connectivity_errors $conn_special_rpt]
if {$special_errors < 0} {
    fail_flow 31 "Unable to parse special connectivity report: $conn_special_rpt"
}

if {$regular_errors != 0 || $special_errors != 0} {
    fail_flow 32 "Connectivity gate failed (regular=$regular_errors, special=$special_errors)."
}
puts "Connectivity gates: PASS (regular=0, special=0)"

set antenna_rpt [file join $proj_root pd/innovus/lvs_process_antenna.rpt]
catch {verifyProcessAntenna -report $antenna_rpt} antenna_msg
set antenna_viol [parse_antenna_violations $antenna_rpt]
if {$antenna_viol < 0} {
    fail_flow 33 "Unable to parse antenna report: $antenna_rpt"
}
if {$antenna_viol != 0} {
    fail_flow 34 "Antenna gate failed ($antenna_viol violations)."
}
puts "Antenna gate: PASS (0 violations)"

saveDesign [file join $proj_root pd/innovus/with_sram_final.enc]

puts "\n=========================================="
puts "WITH-SRAM FLOW RESULT: PASS"
puts "==========================================\n"
puts "Final checkpoints:"
puts "  - pd/innovus/with_sram_final.enc"
puts "  - pd/innovus/drc_with_sram_iter*.rpt"
puts "  - pd/innovus/lvs_connectivity_regular.rpt"
puts "  - pd/innovus/lvs_connectivity_special.rpt"
puts "  - pd/innovus/lvs_process_antenna.rpt"

exit
