# Fresh Innovus walkthrough flow
# Scope of this version:
# - import synthesized design
# - apply global PG/tie connections
# - create floorplan
# - place top-level pins
# - place and fix SRAM macro
# - add reference-style SRAM route blockage
# - cut rows
# - insert endcaps / well taps
# - write checkpoints and verification reports

set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd innovus]}]
set map_out_dir [expr {[info exists ::env(SOC_MAP_OUT_DIR)] && $::env(SOC_MAP_OUT_DIR) ne "" ? [file normalize $::env(SOC_MAP_OUT_DIR)] : [file join $proj_root mapped_with_tech]}]
set enable_endcaps [expr {![info exists ::env(SOC_ENABLE_ENDCAPS)] || $::env(SOC_ENABLE_ENDCAPS) eq "" ? 1 : ($::env(SOC_ENABLE_ENDCAPS) ne "0")}]
set enable_welltaps [expr {[info exists ::env(SOC_ENABLE_WELLTAPS)] && $::env(SOC_ENABLE_WELLTAPS) ne "" ? ($::env(SOC_ENABLE_WELLTAPS) ne "0") : $enable_endcaps}]
set enable_sram_pg_hotspot_blockage [expr {![info exists ::env(SOC_ENABLE_SRAM_PG_HOTSPOT_BLOCKAGE)] || ($::env(SOC_ENABLE_SRAM_PG_HOTSPOT_BLOCKAGE) ne "" && $::env(SOC_ENABLE_SRAM_PG_HOTSPOT_BLOCKAGE) ne "0")}]

file mkdir $pnr_out_dir

# Physical library inputs
set TECH_LEF "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/Tech/APR/N16ADFP_APR_Innovus/N16ADFP_APR_Innovus_11M.10a.tlef"
set STD_LEF  "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/LEF/lef/N16ADFP_StdCell.lef"
set SRAM_LEF "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/IP/sram/N16ADFP_SRAM/LEF/N16ADFP_SRAM_100a.lef"

# Logical handoff from synthesis
set NETLIST   [file join $map_out_dir soc_top.v]
set TOP       "soc_top"
set MMMCFILE  [file join $script_dir innovus_mmmc.tcl]
set SRAM_PATH "u_sram/u_sram_macro"

proc require_file {path} {
    if {![file exists $path]} {
        puts stderr "ERROR: Required file does not exist: $path"
        exit 1
    }
}

proc fail_flow {code msg} {
    puts stderr "ERROR: $msg"
    exit $code
}

proc soc_refresh_pg_connectivity {} {
    globalNetConnect VDD -type pgpin -pin VDD  -all -override
    globalNetConnect VDD -type pgpin -pin VDDM -all -override
    globalNetConnect VDD -type pgpin -pin VPP  -all -override
    globalNetConnect VSS -type pgpin -pin VSS  -all -override
    globalNetConnect VSS -type pgpin -pin VBB  -all -override
    globalNetConnect VDD -type tiehi -all -override
    globalNetConnect VSS -type tielo -all -override
}

proc soc_add_top_signal_pins {} {
    set signal_pins {clk rst_n trap uart_rx uart_tx}
    if {[llength [get_db ports $signal_pins]] == 0} {
        puts "No top-level signal ports found for pin creation; skipping."
        return
    }
    setPinAssignMode -pinEditInBatch true
    editPin -pin $signal_pins \
      -side TOP \
      -layer M8 \
      -spreadType CENTER \
      -spacing 40 \
      -pinWidth 0.40 \
      -pinDepth 0.40 \
      -snap TRACK \
      -fixedPin \
      -fixOverlap
    setPinAssignMode -pinEditInBatch false
    puts "Created physical top pins for: $signal_pins"
}

proc soc_add_endcaps_and_taps {} {
    setEndCapMode -reset
    setEndCapMode \
      -prefix EC \
      -leftEdge {BOUNDARY_LEFTBWP16P90LVT} \
      -rightEdge {BOUNDARY_RIGHTBWP16P90LVT} \
      -topEdge {BOUNDARY_NROW4BWP16P90LVT BOUNDARY_NROW3BWP16P90LVT BOUNDARY_NROW2BWP16P90LVT BOUNDARY_NROW1BWP16P90LVT} \
      -bottomEdge {BOUNDARY_PROW4BWP16P90LVT BOUNDARY_PROW3BWP16P90LVT BOUNDARY_PROW2BWP16P90LVT BOUNDARY_PROW1BWP16P90LVT} \
      -leftTopEdge {BOUNDARY_LEFTBWP16P90LVT} \
      -rightTopEdge {BOUNDARY_RIGHTBWP16P90LVT} \
      -leftBottomEdge {BOUNDARY_LEFTBWP16P90LVT} \
      -rightBottomEdge {BOUNDARY_RIGHTBWP16P90LVT} \
      -leftTopCorner {BOUNDARY_NCORNERBWP16P90LVT} \
      -rightTopCorner {BOUNDARY_NCORNERBWP16P90LVT} \
      -leftBottomCorner {BOUNDARY_PCORNERBWP16P90LVT} \
      -rightBottomCorner {BOUNDARY_PCORNERBWP16P90LVT} \
      -fitGap true \
      -boundary_tap true

    set_well_tap_mode -reset
    set_well_tap_mode \
      -rule 50.76 \
      -bottom_tap_cell {BOUNDARY_NTAPBWP16P90LVT_VPP_VSS} \
      -top_tap_cell {BOUNDARY_PTAPBWP16P90LVT_VPP_VSS} \
      -cell {TAPCELLBWP16P90LVT_VPP_VSS}

    addEndCap -prefix EC

    if {$::enable_welltaps} {
        set_well_tap_mode -reset
        set_well_tap_mode -insert_cells {{TAPCELLBWP16P90LVT_VPP_VSS rule 50.76}}
        addWellTap -checkerBoard
        # verifyWellTap must see the same boundary-aware tap mode used during insertion.
        set_well_tap_mode -reset
        set_well_tap_mode \
          -rule 50.76 \
          -bottom_tap_cell {BOUNDARY_NTAPBWP16P90LVT_VPP_VSS} \
          -top_tap_cell {BOUNDARY_PTAPBWP16P90LVT_VPP_VSS} \
          -cell {TAPCELLBWP16P90LVT_VPP_VSS}
        puts "Inserted boundary cells and well taps."
    } else {
        puts "Inserted boundary cells only."
    }

    verifyEndCap -tripleWell -report [file join $::pnr_out_dir verify_endcap.rpt]
    if {$::enable_welltaps} {
        verifyWellTap -report [file join $::pnr_out_dir verify_welltap.rpt]
    }
}

proc soc_check_physical_boundary_cells {stage} {
    set endcaps [dbGet top.insts.name EC* -e]
    set welltaps [dbGet top.insts.name WELLTAP* -e]
    puts "Physical-cell check at $stage: endcaps=[llength $endcaps] welltaps=[llength $welltaps]"
    if {$::enable_endcaps && [llength $endcaps] == 0} {
        fail_flow 30 "No endcap instances are present at $stage."
    }
    if {$::enable_endcaps && $::enable_welltaps && [llength $welltaps] == 0} {
        fail_flow 31 "No welltap instances are present at $stage."
    }
}

foreach required_file [list $TECH_LEF $STD_LEF $SRAM_LEF $NETLIST $MMMCFILE] {
    require_file $required_file
}

set init_pwr_net VDD
set init_gnd_net VSS
set init_lef_file  [list $TECH_LEF $STD_LEF $SRAM_LEF]
set init_verilog   $NETLIST
set init_top_cell  $TOP
set init_mmmc_file $MMMCFILE

puts ""
puts "=========================================="
puts "Fresh Innovus Walkthrough: Import -> Floorplan -> Boundary Cells"
puts "=========================================="
puts "Project root : $proj_root"
puts "Netlist      : $NETLIST"
puts "MMMC         : $MMMCFILE"
puts "PNR out dir  : $pnr_out_dir"
puts "=========================================="
puts ""

init_design
soc_refresh_pg_connectivity
saveDesign [file join $pnr_out_dir import.enc]

puts ""
puts "=========================================="
puts "Floorplan + Top Pins + SRAM Placement"
puts "=========================================="
puts ""

floorPlan -site core -r 1.0 0.30 50 50 50 50
soc_add_top_signal_pins

set sram_inst [dbGet top.insts.name $SRAM_PATH -p]
if {[llength $sram_inst] == 0} {
    fail_flow 10 "Required SRAM instance '$SRAM_PATH' is missing in netlist."
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
set sram_x_offset [expr {[info exists ::env(SOC_SRAM_X_OFFSET)] && $::env(SOC_SRAM_X_OFFSET) ne "" ? $::env(SOC_SRAM_X_OFFSET) : 0.0}]
set sram_y_offset [expr {[info exists ::env(SOC_SRAM_Y_OFFSET)] && $::env(SOC_SRAM_Y_OFFSET) ne "" ? $::env(SOC_SRAM_Y_OFFSET) : 0.0}]

set min_x [expr {$core_llx + $macro_margin_x}]
set max_x [expr {$core_urx - $macro_margin_x - $sram_w}]
set min_y [expr {$core_lly + $macro_margin_y}]
set max_y [expr {$core_ury - $macro_margin_y - $sram_h}]
set legal_min_x $core_llx
set legal_max_x [expr {$core_urx - $sram_w}]
set legal_min_y $core_lly
set legal_max_y [expr {$core_ury - $sram_h}]
if {$max_x < $min_x || $max_y < $min_y} {
    fail_flow 12 "Core too small for SRAM placement with requested margins."
}

set sram_x [expr {$min_x + $sram_x_offset}]
set sram_y [expr {$min_y + $sram_y_offset}]
if {$sram_x < $legal_min_x || $sram_x > $legal_max_x || $sram_y < $legal_min_y || $sram_y > $legal_max_y} {
    fail_flow 13 "Requested SRAM offset places macro outside legal core placement window."
}
placeInstance $SRAM_PATH $sram_x $sram_y R0
setInstancePlacementStatus -name $SRAM_PATH -status fixed
puts "SRAM macro placed at ($sram_x, $sram_y) and fixed."

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
puts "Added SRAM signal blockage (M5/M6, PG exempt)."

if {$enable_sram_pg_hotspot_blockage} {
    set pg_ko_llx [expr {$s_urx - 0.05}]
    set pg_ko_lly [expr {$s_lly - 1.0}]
    set pg_ko_urx [expr {$s_urx + 1.10}]
    set pg_ko_ury [expr {$s_lly + 3.50}]
    createRouteBlk -name sram_pg_m4_hotspot -layer {M4} -box [list $pg_ko_llx $pg_ko_lly $pg_ko_urx $pg_ko_ury]
    puts "Added SRAM PG hotspot blockage on M4."
} else {
    puts "Skipping SRAM PG hotspot blockage on M4."
}

cutRow
checkFPlan -outFile [file join $pnr_out_dir checkFPlan.rpt]

puts ""
puts "=========================================="
puts "Endcaps + Well Taps"
puts "=========================================="
puts ""

if {$enable_endcaps} {
    soc_add_endcaps_and_taps
    soc_check_physical_boundary_cells post_boundary_insertion
} else {
    puts "Skipping endcap/tap insertion."
}

saveDesign [file join $pnr_out_dir boundary.enc]

puts ""
puts "Batch walkthrough complete."
puts "Import checkpoint  : [file join $pnr_out_dir import.enc]"
puts "Boundary checkpoint: [file join $pnr_out_dir boundary.enc]"
puts "Reports:"
puts "  [file join $pnr_out_dir checkFPlan.rpt]"
puts "  [file join $pnr_out_dir verify_endcap.rpt]"
puts "  [file join $pnr_out_dir verify_welltap.rpt]"
puts ""
