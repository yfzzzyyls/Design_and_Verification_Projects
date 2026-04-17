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
    set total 0
    foreach line [split $content "\n"] {
        if {[regexp {^\s*([0-9]+)\s+Problem\(s\)} $line -> num]} {
            incr total $num
        }
    }
    if {$total > 0} {
        return $total
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

set route_enc [expr {[info exists ::env(SOC_ROUTE_ENC)] && $::env(SOC_ROUTE_ENC) ne "" ? [file normalize $::env(SOC_ROUTE_ENC)] : ""}]
set out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd route_checkpoint_check]}]

if {$route_enc eq ""} {
    fail_flow 10 "SOC_ROUTE_ENC is not set"
}
file mkdir $out_dir

if {[file isdirectory $route_enc]} {
    set restore_target $route_enc
} elseif {[file exists "${route_enc}.dat"]} {
    set restore_target "${route_enc}.dat"
} else {
    set restore_target $route_enc
}

restoreDesign $restore_target soc_top

set drc_rpt [file join $out_dir route_checkpoint_drc.rpt]
verify_drc -limit 10000 -report $drc_rpt
set drc_viol [parse_drc_violations $drc_rpt]
puts "Route-checkpoint DRC: $drc_viol"

set conn_regular_rpt [file join $out_dir route_checkpoint_regular.rpt]
verifyConnectivity -type regular -error 1000 -warning 100 -report $conn_regular_rpt
set regular_errors [parse_connectivity_errors $conn_regular_rpt]
puts "Route-checkpoint regular connectivity: $regular_errors"

set conn_special_rpt [file join $out_dir route_checkpoint_special.rpt]
verifyConnectivity -type special -noAntenna -error 1000 -warning 100 -report $conn_special_rpt
set special_errors [parse_connectivity_errors $conn_special_rpt]
puts "Route-checkpoint special connectivity: $special_errors"

set antenna_rpt [file join $out_dir route_checkpoint_antenna.rpt]
catch {verifyProcessAntenna -report $antenna_rpt} antenna_msg
set antenna_viol [parse_antenna_violations $antenna_rpt]
puts "Route-checkpoint antenna: $antenna_viol"

saveDesign [file join $out_dir route_checkpoint_checked.enc]
exit
