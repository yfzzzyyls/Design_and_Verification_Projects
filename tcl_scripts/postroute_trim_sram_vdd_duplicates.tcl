set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd postroute_trim_sram_vdd_duplicates]}]
set route_enc [expr {[info exists ::env(SOC_ROUTE_ENC)] && $::env(SOC_ROUTE_ENC) ne "" ? [file normalize $::env(SOC_ROUTE_ENC)] : [file join $proj_root pd innovus_resume_place_sram_pgfix_20260409 with_sram_route.enc.dat]}]
file mkdir $pnr_out_dir

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

proc soc_add_fill_region_if_valid {layers llx lly urx ury} {
    if {$urx <= $llx || $ury <= $lly} { return }
    addMetalFill -layer $layers -timingAware sta -area "$llx $lly $urx $ury"
}

proc soc_add_fill_with_trap_m4_keepout {llx lly urx ury} {
    set fill_ko_llx 143.45
    set fill_ko_lly 94.35
    set fill_ko_urx 144.15
    set fill_ko_ury 95.45
    set sram_ko_llx 104.30
    set sram_ko_lly 60.80
    set sram_ko_urx 106.10
    set sram_ko_ury 65.40

    soc_add_fill_region_if_valid {M1 M2 M3 M6} $llx $lly $urx $ury
    soc_add_fill_region_if_valid {M5} $llx $lly $urx $fill_ko_lly
    soc_add_fill_region_if_valid {M5} $llx $fill_ko_ury $urx $ury
    soc_add_fill_region_if_valid {M5} $llx $fill_ko_lly $fill_ko_llx $fill_ko_ury
    soc_add_fill_region_if_valid {M5} $fill_ko_urx $fill_ko_lly $urx $fill_ko_ury
    soc_add_fill_region_if_valid {M4} $llx $lly $urx $sram_ko_lly
    soc_add_fill_region_if_valid {M4} $llx $sram_ko_ury $urx $ury
    soc_add_fill_region_if_valid {M4} $llx $sram_ko_lly $sram_ko_llx $sram_ko_ury
    soc_add_fill_region_if_valid {M4} $sram_ko_urx $sram_ko_lly $urx $sram_ko_ury
}

proc soc_insert_standard_cell_fillers {} {
    set filler_cells {
        DCAP64BWP20P90 DCAP64BWP16P90 DCAP64BWP20P90LVT DCAP64BWP16P90LVT
        DCAP32BWP20P90 DCAP32BWP16P90 DCAP32BWP20P90LVT DCAP32BWP16P90LVT
        DCAP16BWP20P90 DCAP16BWP16P90 DCAP16BWP20P90LVT DCAP16BWP16P90LVT
        DCAP8BWP20P90 DCAP8BWP16P90 DCAP8BWP20P90LVT DCAP8BWP16P90LVT
        DCAP4BWP20P90 DCAP4BWP16P90 DCAP4BWP20P90LVT DCAP4BWP16P90LVT
        FILL64BWP20P90 FILL64BWP16P90 FILL64BWP20P90LVT FILL64BWP16P90LVT
        FILL32BWP20P90 FILL32BWP16P90 FILL32BWP20P90LVT FILL32BWP16P90LVT
        FILL16BWP20P90 FILL16BWP16P90 FILL16BWP20P90LVT FILL16BWP16P90LVT
        FILL8BWP20P90 FILL8BWP16P90 FILL8BWP20P90LVT FILL8BWP16P90LVT
        FILL4BWP20P90 FILL4BWP16P90 FILL4BWP20P90LVT FILL4BWP16P90LVT
        FILL3BWP20P90 FILL3BWP16P90 FILL3BWP20P90LVT FILL3BWP16P90LVT
        FILL2BWP20P90 FILL2BWP16P90 FILL2BWP20P90LVT FILL2BWP16P90LVT
        FILL1BWP20P90 FILL1BWP16P90 FILL1BWP20P90LVT FILL1BWP16P90LVT
    }
    setPlaceMode -place_detail_use_no_diffusion_one_site_filler true
    setPlaceMode -place_detail_no_filler_without_implant true
    setPlaceMode -place_detail_check_diffusion_forbidden_spacing true
    setFillerMode -core $filler_cells -preserveUserOrder true -fitGap true \
        -corePrefix FILLER -add_fillers_with_drc false -check_signal_drc true
    addFiller
    checkFiller
    checkPlace
}

proc soc_get_design_bbox {} {
    set bbox_raw [get_db designs .bbox]
    set bbox [join $bbox_raw]
    if {[llength $bbox] != 4} {
        fail_flow 13 "Unexpected design bbox format: $bbox_raw"
    }
    return $bbox
}

proc trim_duplicate_m4_shapes {} {
    # Delete only the outer upper M4 box and the lower right-side duplicate,
    # leaving the left trunk box intact so VDD connectivity can survive.
    set delete_boxes {
        {105.040 64.740 105.271 64.860}
        {105.318 61.300 105.390 61.800}
    }
    set total_deleted 0
    foreach box $delete_boxes {
        deselectAll
        editSelect -net VDD -type Special -layer M4 -area $box
        set sel_count [llength [dbGet selected]]
        puts "Delete box $box selected $sel_count object(s)"
        if {$sel_count > 0} {
            catch {puts "Delete boxes actual: [dbGet selected.box]"}
            editDelete -selected
            incr total_deleted $sel_count
        }
    }
    deselectAll
    if {$total_deleted == 0} {
        fail_flow 40 "No duplicate M4 hotspot shapes were deleted."
    }
}

puts "\n=========================================="
puts "POST-ROUTE TRIM SRAM VDD DUPLICATES"
puts "==========================================\n"

restoreDesign $route_enc soc_top
soc_insert_standard_cell_fillers
soc_refresh_pg_connectivity

set bbox [soc_get_design_bbox]
set llx [lindex $bbox 0]
set lly [lindex $bbox 1]
set urx [lindex $bbox 2]
set ury [lindex $bbox 3]
soc_add_fill_with_trap_m4_keepout $llx $lly $urx $ury

set rpt0 [file join $pnr_out_dir drc_with_sram_iter0.rpt]
verify_drc -limit 10000 -report $rpt0
puts "Iter0 DRC: [parse_drc_violations $rpt0]"

catch {ecoRoute -fix_drc}
set rpt1 [file join $pnr_out_dir drc_with_sram_iter1.rpt]
verify_drc -limit 10000 -report $rpt1
set drc1 [parse_drc_violations $rpt1]
puts "Iter1 DRC: $drc1"
if {$drc1 != 4} {
    fail_flow 41 "Expected 4 residual hotspot violations after first ecoRoute, saw $drc1."
}

trim_duplicate_m4_shapes
catch {ecoRoute -fix_drc}
set rpt2 [file join $pnr_out_dir drc_with_sram_iter2_trimmed.rpt]
verify_drc -limit 10000 -report $rpt2
set drc2 [parse_drc_violations $rpt2]
puts "Trimmed DRC: $drc2"
if {$drc2 != 0} {
    fail_flow 42 "Duplicate trim did not clear DRC (remaining $drc2)."
}

set conn_regular_rpt [file join $pnr_out_dir lvs_connectivity_regular.rpt]
verifyConnectivity -type regular -error 1000 -warning 100 -report $conn_regular_rpt
set regular_errors [parse_connectivity_errors $conn_regular_rpt]
if {$regular_errors != 0} {
    fail_flow 43 "Regular connectivity failed after duplicate trim ($regular_errors)."
}

set conn_special_rpt [file join $pnr_out_dir lvs_connectivity_special.rpt]
verifyConnectivity -type special -noAntenna -error 1000 -warning 100 -report $conn_special_rpt
set special_errors [parse_connectivity_errors $conn_special_rpt]
if {$special_errors != 0} {
    fail_flow 44 "Special connectivity failed after duplicate trim ($special_errors)."
}

saveDesign [file join $pnr_out_dir with_sram_final.enc]
puts "\n=========================================="
puts "DUPLICATE TRIM RESULT: PASS"
puts "==========================================\n"
exit
