set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]

if {![info exists ::env(SOC_FINAL_ENC)] || $::env(SOC_FINAL_ENC) eq ""} {
    puts "ERROR: SOC_FINAL_ENC is not set"
    exit 2
}
if {![info exists ::env(SOC_SIGNOFF_EXPORT_DIR)] || $::env(SOC_SIGNOFF_EXPORT_DIR) eq ""} {
    puts "ERROR: SOC_SIGNOFF_EXPORT_DIR is not set"
    exit 3
}

set final_enc   [file normalize $::env(SOC_FINAL_ENC)]
set export_dir  [file normalize $::env(SOC_SIGNOFF_EXPORT_DIR)]
set design_name [expr {[info exists ::env(SOC_DESIGN_NAME)] && $::env(SOC_DESIGN_NAME) ne "" ? $::env(SOC_DESIGN_NAME) : "soc_top"}]
set gds_map     "/ip/tsmc/tsmc16adfp/source/DAFP0203001_2_X/Executable_Package/Collaterals/Tech/APR/N16ADFP_APR_Innovus/N16ADFP_APR_Innovus_Gdsout_11M.10a.map"
set stream_units [expr {[info exists ::env(SOC_STREAM_UNITS)] && $::env(SOC_STREAM_UNITS) ne "" ? $::env(SOC_STREAM_UNITS) : "2000"}]
set layout_format [string tolower [expr {[info exists ::env(SOC_LAYOUT_FORMAT)] && $::env(SOC_LAYOUT_FORMAT) ne "" ? $::env(SOC_LAYOUT_FORMAT) : "oasis"}]]
set export_pg_pins [expr {![info exists ::env(SOC_EXPORT_PG_PINS)] || $::env(SOC_EXPORT_PG_PINS) eq "" ? 1 : [string is true -strict $::env(SOC_EXPORT_PG_PINS)]}]

proc soc_term_has_pin_shape {term_name} {
    set term_ptr [dbGet -p top.terms.name $term_name]
    if {$term_ptr eq "" || $term_ptr eq "0x0"} {
        return 0
    }
    set shapes [dbGet $term_ptr.pins.allShapes]
    if {$shapes eq "" || $shapes eq "0x0"} {
        return 0
    }
    return [expr {[llength $shapes] > 0}]
}

proc soc_find_pg_ring_box {net_name target_layer target_width} {
    set net_ptr [dbGet -p top.nets.name $net_name]
    if {$net_ptr eq "" || $net_ptr eq "0x0"} {
        return ""
    }
    set layers [dbGet $net_ptr.sWires.layer.name]
    set widths [dbGet $net_ptr.sWires.width]
    set boxes  [dbGet $net_ptr.sWires.box]
    set count [llength $layers]
    for {set i 0} {$i < $count} {incr i} {
        set layer_name [lindex $layers $i]
        set width_val  [lindex $widths $i]
        set box_val    [lindex $boxes $i]
        if {$layer_name eq $target_layer && [expr {abs(double($width_val) - double($target_width)) < 0.001}]} {
            return $box_val
        }
    }
    return ""
}

proc soc_find_signal_attach_shape {net_name} {
    set net_ptr [dbGet -p top.nets.name $net_name]
    if {$net_ptr eq "" || $net_ptr eq "0x0"} {
        return ""
    }
    array set best_rank {}
    foreach preferred_layer {M5 M4 M3 M2 M1} {
        set best_rank($preferred_layer) 1
    }
    set layers [dbGet $net_ptr.wires.layer.name]
    set boxes  [dbGet $net_ptr.wires.box]
    set count [llength $layers]
    for {set i 0} {$i < $count} {incr i} {
        set layer [lindex $layers $i]
        set box   [lindex $boxes $i]
        if {$layer eq "" || $layer eq "0x0" || $box eq "" || $box eq "0x0"} {
            continue
        }
        if {[info exists best_rank($layer)]} {
            return [list $layer $box]
        }
    }
    return ""
}

if {[file isdirectory $final_enc]} {
    set restore_target $final_enc
} elseif {[file exists "${final_enc}.dat"]} {
    set restore_target "${final_enc}.dat"
} else {
    set restore_target $final_enc
}

file mkdir $export_dir

puts "Restoring final checkpoint: $restore_target"
restoreDesign $restore_target $design_name

deleteEmptyModule

# Re-apply global PG intent for export so saveNetlist emits the same library
# supply/well-pin connectivity that Calibre expects for boxed stdcells/decaps.
foreach {net_name pin_name} {
    VDD VDD
    VDD VDDM
    VSS VSS
    VDD VPP
    VSS VBB
} {
    if {[catch {globalNetConnect $net_name -type pgpin -pin $pin_name -all -override} gnc_err]} {
        puts "WARN: globalNetConnect $net_name/$pin_name failed during export: $gnc_err"
    }
}
foreach {net_name conn_type} {
    VDD tiehi
    VSS tielo
} {
    if {[catch {globalNetConnect $net_name -type $conn_type -all -override} gnc_err]} {
        puts "WARN: globalNetConnect $net_name/$conn_type failed during export: $gnc_err"
    }
}

# The clean soc_design baseline leaves the three top IO terms abstract-only.
# For signoff export, always add a pin shape on real routed geometry so Calibre
# sees the same top-level connectivity as Innovus.
set export_pins [list]
foreach term_name {clk rst_n trap uart_rx uart_tx} {
    set term_ptr [dbGet -p top.terms.name $term_name]
    if {$term_ptr ne "" && $term_ptr ne "0x0"} {
        lappend export_pins $term_name
    }
}
if {[llength $export_pins] > 0} {
    puts "Checking physical IO pin shapes for export: $export_pins"
    foreach term_name $export_pins {
        set attach_shape [soc_find_signal_attach_shape $term_name]
        if {$attach_shape ne ""} {
            set attach_layer [lindex $attach_shape 0]
            set attach_box   [lindex $attach_shape 1]
            if {[soc_term_has_pin_shape $term_name]} {
                puts "Adding export-time attach pin shape for $term_name on $attach_layer at routed box $attach_box"
            } else {
                puts "Creating temporary physical IO pin for $term_name on $attach_layer at routed box $attach_box"
            }
            if {[catch {eval createPhysicalPin $term_name -net $term_name -samePort -layer $attach_layer -rect $attach_box} pin_err]} {
                puts "WARN: createPhysicalPin failed for $term_name: $pin_err"
                setPinAssignMode -pinEditInBatch true
                editPin -pin $term_name \
                    -side LEFT \
                    -layer $attach_layer \
                    -spreadType CENTER \
                    -spacing 20 \
                    -pinWidth 0.40 \
                    -pinDepth 0.40 \
                    -snap MGRID \
                    -fixedPin \
                    -fixOverlap
                setPinAssignMode -pinEditInBatch false
            }
        } else {
            puts "WARN: Could not find routed geometry for $term_name, falling back to boundary editPin"
            setPinAssignMode -pinEditInBatch true
            editPin -pin $term_name \
                -side LEFT \
                -layer M4 \
                -spreadType CENTER \
                -spacing 20 \
                -pinWidth 0.20 \
                -pinDepth 0.20 \
                -snap MGRID \
                -fixedPin \
                -fixOverlap
            setPinAssignMode -pinEditInBatch false
        }
    }
}

if {$export_pg_pins} {
    # The signoff export also needs explicit named PG pins on real routed ring
    # shapes so Calibre can identify POWER/GROUND nets in the layout.
    foreach {pg_net pg_layer pg_width} {VDD M9 2.0 VSS M9 2.0} {
        set pg_box [soc_find_pg_ring_box $pg_net $pg_layer $pg_width]
        if {$pg_box eq ""} {
            puts "WARN: Could not locate $pg_net ring box on $pg_layer for export pin creation"
            continue
        }
        if {[catch {eval createPGPin $pg_net -net $pg_net -geom $pg_layer $pg_box} err]} {
            puts "WARN: createPGPin for $pg_net failed during export: $err"
        } else {
            puts "Created temporary named PG pin for $pg_net on $pg_layer at $pg_box"
        }
    }
} else {
    puts "Skipping temporary PG export pin creation"
}

set dbgLefDefOutVersion 5.8
set dbgDefOutLefVias 1
set defOutLefNDR 1
set dbgDefOutFixedViaShape 1

saveNetlist [file join $export_dir ${design_name}.v]
defOut -floorplan -netlist -routing -usedVia -skip_trimmetal_layers [file join $export_dir ${design_name}.def.gz]

setStreamOutMode -virtualConnection false -labelAllPinShape true
setStreamOutMode -specifyViaName %t_%v_%l(lcu)_%n_%r_%c_%u -SEvianames true
if {$layout_format eq "gds" || $layout_format eq "gdsii"} {
    streamOut -mode ALL -outputMacros -format stream -units $stream_units -mapFile $gds_map -libName DesignLib -attachNetName 1 -attachInstanceName 1 -dieAreaAsBoundary [file join $export_dir ${design_name}.gds]
} else {
    streamOut -mode ALL -outputMacros -format oasis -units $stream_units -mapFile $gds_map -libName DesignLib -attachNetName 1 -attachInstanceName 1 -dieAreaAsBoundary [file join $export_dir ${design_name}.oas.gz]
}

set DECAP_CELL_LIST   [dbGet -e [dbGet head.libCells {[string match DCAP* .name] || [string match DECAP* .name]}].name]
set PVDD_CELL_LIST    [dbGet -e [dbGet head.libCells {[string match PVDD* .name]}].name]
set FILLER_CELL_LIST  [dbGet -e [dbGet head.libCells {[string match FILL* .name]}].name]
set TAP_CELL_LIST     [lsort -u [dbGet -e top.insts.cell.name TAPCELL*]]
set BOUNDARY_CELL_LIST [lsort -u [dbGet -e top.insts.cell.name BOUNDARY_*]]
set PCORNER_NETLIST_CELL_LIST [lsort -u [dbGet -e top.insts.cell.name PCORNER*]]
set PFILLER_CELL_LIST [lsort -u [dbGet -e top.insts.cell.name PFILLER*]]
set PCORNER_CELL_LIST [lsort -u [dbGet -e top.insts.cell.name PCORNER*]]

saveNetlist [file join $export_dir ${design_name}.lvsvg] \
    -excludeLeafCell \
    -includePowerGround \
    -includePhysicalCell "$DECAP_CELL_LIST $PVDD_CELL_LIST $FILLER_CELL_LIST $TAP_CELL_LIST $BOUNDARY_CELL_LIST $PCORNER_NETLIST_CELL_LIST" \
    -excludeCellInst "$PFILLER_CELL_LIST $PCORNER_CELL_LIST"

puts "Calibre export complete:"
puts "  [file join $export_dir ${design_name}.v]"
puts "  [file join $export_dir ${design_name}.def.gz]"
if {$layout_format eq "gds" || $layout_format eq "gdsii"} {
    puts "  [file join $export_dir ${design_name}.gds]"
} else {
    puts "  [file join $export_dir ${design_name}.oas.gz]"
}
puts "  [file join $export_dir ${design_name}.lvsvg]"

exit
