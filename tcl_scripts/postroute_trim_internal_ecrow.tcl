set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]

set base_enc [expr {[info exists ::env(SOC_BASE_ENC)] && $::env(SOC_BASE_ENC) ne "" ? [file normalize $::env(SOC_BASE_ENC)] : [file join $proj_root pd innovus_rowedge_nolvt_20260410 with_sram_postdrc.enc.dat]}]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd innovus_rowedge_trimmed_20260410]}]
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

restoreDesign $base_enc soc_top

set core_box [dbGet top.fplan.coreBox -e]
set core_llx [lindex $core_box 0]
set core_urx [lindex $core_box 2]
set die_box [dbGet top.fPlan.box]
set edge_tol 0.001
set deleted 0

foreach inst_ptr [dbQuery -area $die_box -objType inst] {
    set inst [dbGet $inst_ptr.name]
    if {![string match "ECROW_*" $inst]} {
        continue
    }
    set box [dbGet $inst_ptr.box]
    if {[llength $box] != 4} {
        continue
    }
    set llx [lindex $box 0]
    set urx [lindex $box 2]
    set on_left_edge [expr {abs($llx - $core_llx) <= $edge_tol}]
    set on_right_edge [expr {abs($urx - $core_urx) <= $edge_tol}]
    if {!$on_left_edge && !$on_right_edge} {
        deleteInst $inst
        incr deleted
    }
}

set drc_rpt [file join $pnr_out_dir drc_with_sram_iter0.rpt]
verify_drc -limit 10000 -report $drc_rpt
set drc_viol [parse_drc_violations $drc_rpt]
if {$drc_viol > 0} {
    catch {ecoRoute -fix_drc}
    set drc_rpt [file join $pnr_out_dir drc_with_sram_iter1.rpt]
    verify_drc -limit 10000 -report $drc_rpt
    set drc_viol [parse_drc_violations $drc_rpt]
}

saveDesign [file join $pnr_out_dir with_sram_final.enc]
puts "ECROW_TRIM_SUMMARY deleted=$deleted drc=$drc_viol"
exit
