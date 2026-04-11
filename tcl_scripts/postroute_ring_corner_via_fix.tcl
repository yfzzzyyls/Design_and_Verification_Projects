set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd postroute_ring_corner_via_fix]}]
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

proc soc_add_fill_region_if_valid {layers llx lly urx ury} {
    if {$urx <= $llx || $ury <= $lly} { return }
    addMetalFill -layer $layers -timingAware sta -area "$llx $lly $urx $ury"
}

proc soc_add_fill_with_keepouts {llx lly urx ury} {
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
    return $bbox
}

restoreDesign $route_enc soc_top
soc_insert_standard_cell_fillers
soc_refresh_pg_connectivity
set bbox [soc_get_design_bbox]
soc_add_fill_with_keepouts [lindex $bbox 0] [lindex $bbox 1] [lindex $bbox 2] [lindex $bbox 3]

set max_eco_iters 8
set eco_iter 0
set drc_pre [file join $pnr_out_dir drc_iter0.rpt]
verify_drc -limit 10000 -report $drc_pre
set drc_viol [parse_drc_violations $drc_pre]
while {$drc_viol > 0 && $eco_iter < $max_eco_iters} {
    incr eco_iter
    catch {ecoRoute -fix_drc}
    set drc_pre [file join $pnr_out_dir drc_iter${eco_iter}.rpt]
    verify_drc -limit 10000 -report $drc_pre
    set drc_viol [parse_drc_violations $drc_pre]
}

editPowerVia \
    -nets {VDD VSS} \
    -bottom_layer M9 \
    -top_layer M10 \
    -create_via_on_merged_target_on_layer M9 \
    -create_via_on_merged_target_within 2.1 \
    -add_vias 1 \
    -orthogonal_only 0

set drc_rpt [file join $pnr_out_dir drc_final.rpt]
set reg_rpt [file join $pnr_out_dir lvs_connectivity_regular.rpt]
set spc_rpt [file join $pnr_out_dir lvs_connectivity_special.rpt]

verify_drc -limit 10000 -report $drc_rpt
verifyConnectivity -type regular -error 1000 -warning 100 -report $reg_rpt
verifyConnectivity -type special -noAntenna -error 2000 -warning 100 -report $spc_rpt

saveDesign [file join $pnr_out_dir with_sram_ring_corner_fix.enc]
puts "RING_CORNER_FIX_SUMMARY DRC=[parse_drc_violations $drc_rpt] REG=[parse_connectivity_errors $reg_rpt] SPC=[parse_connectivity_errors $spc_rpt]"
exit
