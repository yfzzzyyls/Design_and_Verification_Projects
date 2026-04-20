# Innovus bring-up script (baseline import/floorplan)
# Paths assume this repo layout and the TSMC16 collateral tree mounted at /ip/tsmc/tsmc16adfp.

# Resolve project root (folder containing this script's parent)
set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]
set enable_endcaps [expr {![info exists ::env(SOC_ENABLE_ENDCAPS)] || $::env(SOC_ENABLE_ENDCAPS) eq "" ? 1 : ($::env(SOC_ENABLE_ENDCAPS) ne "0")}]
set enable_welltaps [expr {[info exists ::env(SOC_ENABLE_WELLTAPS)] && $::env(SOC_ENABLE_WELLTAPS) ne "" ? ($::env(SOC_ENABLE_WELLTAPS) ne "0") : $enable_endcaps}]

# Library and design inputs
set TECH_LEF  "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/Tech/APR/N16ADFP_APR_Innovus/N16ADFP_APR_Innovus_11M.10a.tlef"
set STD_LEF   "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/LEF/lef/N16ADFP_StdCell.lef"
set SRAM_LEF  "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/IP/sram/N16ADFP_SRAM/LEF/N16ADFP_SRAM_100a.lef"

set STD_GDS   "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/GDS/N16ADFP_StdCell.gds"
set SRAM_GDS  "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/IP/sram/N16ADFP_SRAM/GDS/N16ADFP_SRAM_100a.gds"

set NETLIST   [file join $proj_root mapped soc_top.v]
set TOP       "soc_top"

# Canonical MMMC file for timing setup
set MMMC_FILE [file normalize [file join $script_dir innovus_mmmc.tcl]]

# Power nets (adjust if your LEF uses different names)
set init_pwr_net VDD
set init_gnd_net VSS

# Use LEGACY init mode - this is the only mode where floorPlan command exists
set init_lef_file   [list $TECH_LEF $STD_LEF $SRAM_LEF]
set init_verilog    $NETLIST
set init_top_cell   $TOP
set init_mmmc_file  $MMMC_FILE

# Initialize design (timing libraries loaded via init_mmmc_file)
init_design

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
    # Reserve the outermost site on each row with fixed boundary cells so later
    # placement cannot consume the row-edge slots that Calibre expects to be capped.
    set edge_w 0.09
    set edge_idx 0
    set core_box [join [dbGet top.fplan.coreBox -e]]
    set core_llx [expr {double([lindex $core_box 0])}]
    set core_urx [expr {double([lindex $core_box 2])}]
    set edge_tol 0.001
    set row_boxes [dbGet top.fplan.rows.box -e]
    set row_orients [dbGet top.fplan.rows.orient -e]
    foreach box $row_boxes orient $row_orients {
        set flat_box [join $box]
        if {[llength $flat_box] != 4} {
            continue
        }
        set llx [expr {double([lindex $flat_box 0])}]
        set lly [expr {double([lindex $flat_box 1])}]
        set urx [expr {double([lindex $flat_box 2])}]
        if {$urx <= ($llx + (2.0 * $edge_w))} {
            continue
        }
        if {[expr {abs($llx - $core_llx)}] <= $edge_tol} {
            incr edge_idx
            set left_name ECROW_L_$edge_idx
            addInst -cell BOUNDARY_LEFTBWP16P90 -inst $left_name -loc [list $llx $lly] -ori $orient -place_status fixed
        }
        if {[expr {abs($urx - $core_urx)}] <= $edge_tol} {
            incr edge_idx
            set right_name ECROW_R_$edge_idx
            addInst -cell BOUNDARY_RIGHTBWP16P90 -inst $right_name -loc [list [expr {$urx - $edge_w}] $lly] -ori $orient -place_status fixed
        }
    }
    puts "Inserted $edge_idx manual die-edge row endcaps."

    setEndCapMode -reset
    setEndCapMode \
        -prefix EC \
        -rightEdge {BOUNDARY_LEFTBWP16P90} \
        -leftEdge {BOUNDARY_RIGHTBWP16P90} \
        -leftTopCorner {BOUNDARY_PCORNERBWP16P90} \
        -leftBottomCorner {BOUNDARY_NCORNERBWP16P90} \
        -topEdge {BOUNDARY_PROW1BWP16P90 BOUNDARY_PROW2BWP16P90 BOUNDARY_PROW3BWP16P90 BOUNDARY_PROW4BWP16P90} \
        -bottomEdge {BOUNDARY_NROW1BWP16P90 BOUNDARY_NROW2BWP16P90 BOUNDARY_NROW3BWP16P90 BOUNDARY_NROW4BWP16P90} \
        -leftTopEdge {FILL3BWP16P90} \
        -leftBottomEdge {FILL3BWP16P90} \
        -fitGap true \
        -boundary_tap true
    set_well_tap_mode \
        -rule 50.76 \
        -bottom_tap_cell {BOUNDARY_NTAPBWP16P90} \
        -top_tap_cell {BOUNDARY_PTAPBWP16P90} \
        -cell {TAPCELLBWP16P90}
    addEndCap -prefix EC
    if {$::enable_welltaps} {
        set_well_tap_mode -reset
        set_well_tap_mode -insert_cells {{TAPCELLBWP16P90 rule 50.76}}
        addWellTap -checkerBoard
        verifyWellTap -report ../pd/innovus/verify_welltap_init.rpt
        puts "Inserted boundary cells and well taps."
    } else {
        puts "Inserted boundary cells only."
    }
    verifyEndCap -report ../pd/innovus/verify_endcap_init.rpt
}

proc soc_check_physical_boundary_cells {stage} {
    set endcaps [dbGet top.insts.name EC* -e]
    set welltaps [dbGet top.insts.name WELLTAP* -e]
    puts "Physical-cell check at $stage: endcaps=[llength $endcaps] welltaps=[llength $welltaps]"
    if {$::enable_endcaps && [llength $endcaps] == 0} {
        error "No endcap instances are present at $stage."
    }
    if {$::enable_endcaps && $::enable_welltaps && [llength $welltaps] == 0} {
        error "No welltap instances are present at $stage."
    }
}

# Create floorplan - floorPlan command IS available in legacy batch mode
# Ultra-low utilization (30%) for maximum DRC cleanness - course project setting
# Maximum routing space to eliminate short wire segments
floorPlan -site core -r 1.0 0.30 50 50 50 50

soc_add_top_signal_pins

# Place and fix the SRAM macro; adjust coordinates/orientation to taste.
set sram_inst [get_db insts u_sram/u_sram_macro]
if { [llength $sram_inst] > 0 } {
  placeInstance $sram_inst 50 50 R0
  set_db $sram_inst .place_status fixed
}

cutRow

if {$enable_endcaps} {
    soc_add_endcaps_and_taps
    soc_check_physical_boundary_cells post_boundary_insertion
} else {
    puts "Skipping endcap/tap insertion."
}

# Save an initial design checkpoint
saveDesign ../pd/innovus/init.enc
