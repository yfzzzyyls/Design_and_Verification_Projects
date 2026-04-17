set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]
set pnr_out_dir [expr {[info exists ::env(SOC_PNR_OUT_DIR)] && $::env(SOC_PNR_OUT_DIR) ne "" ? [file normalize $::env(SOC_PNR_OUT_DIR)] : [file join $proj_root pd postroute_sparse_backbone_pgfix]}]
set route_enc [expr {[info exists ::env(SOC_ROUTE_ENC)] && $::env(SOC_ROUTE_ENC) ne "" ? [file normalize $::env(SOC_ROUTE_ENC)] : [file join $proj_root pd innovus_axi_uartcordic_rowmesh_nom1c_20260411_201037 with_sram_route.enc.dat]}]
set skip_floating_stripe [expr {[info exists ::env(SOC_SKIP_FLOATING_STRIPE)] && $::env(SOC_SKIP_FLOATING_STRIPE) ne "" && $::env(SOC_SKIP_FLOATING_STRIPE) ne "0"}]
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

proc parse_connectivity_total {rpt} {
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

proc soc_refresh_pg_connectivity {} {
    globalNetConnect VDD -type pgpin -pin VDD -all -override
    globalNetConnect VDD -type pgpin -pin VDDM -all -override
    globalNetConnect VDD -type pgpin -pin VPP -all -override
    globalNetConnect VSS -type pgpin -pin VSS -all -override
    globalNetConnect VSS -type pgpin -pin VBB -all -override
    globalNetConnect VDD -type tiehi -all -override
    globalNetConnect VSS -type tielo -all -override
}

variable curRegionBKG

proc P_VIA_GEN_MODE {} {
    setViaGenMode -reset
    setViaGenMode \
        -ignore_DRC 0 \
        -allow_via_expansion 0 \
        -extend_out_wire_end 1 \
        -inherit_wire_status 1 \
        -keep_existing_via 2 \
        -partial_overlap_threshold 1 \
        -allow_wire_shape_change 0 \
        -keep_fixed_via 1 \
        -optimize_cross_via 1 \
        -disable_via_merging 1 \
        -use_cce 1 \
        -use_fgc 1
}

proc P_PG_GEN_MODE {layer} {
    set topLayerNum [expr {[dbget [dbget head.layers.name $layer -p].num] + 1}]
    set topLayer    [dbget [dbget head.layers.num $topLayerNum -p].name -e]

    setAddStripeMode -reset
    setAddStripeMode \
        -use_fgc 1 \
        -remove_floating_stripe_over_block false \
        -stacked_via_bottom_layer $layer \
        -stacked_via_top_layer $topLayer \
        -keep_pitch_after_snap false \
        -via_using_exact_crossover_size false \
        -ignore_nondefault_domains true \
        -skip_via_on_pin {Pad Block Cover Standardcell Physicalpin} \
        -stapling_nets_style end_to_end \
        -remove_floating_stapling true
    setAddStripeMode -ignore_DRC 0
}

proc initializeRegionBKG {} {
    variable curRegionBKG
    array unset curRegionBKG

    set Die  [dbget top.fplan.box -e]
    set Core [dbget top.fplan.coreBox -e]
    set STD  [dbget top.fplan.rows.box -e]

    set curRegionBKG(Core) [dbshape $Die ANDNOT $Core -output rect]
    set curRegionBKG(STD)  [dbshape $Die ANDNOT [dbShape $STD SIZEY 0.1] -output rect]
}

proc createPowerStripe {region direction layer nets offset width spacing pitch {extra_blockage ""}} {
    variable curRegionBKG

    if {[lindex $nets 1] > 1} {
        set spacing [lrepeat [expr {[lindex $nets 1] - 1}] $spacing]
    }
    set nets      [lrepeat [lindex $nets 1] [lindex $nets 0]]
    set direction [expr {$direction eq "H" ? "horizontal" : "vertical"}]
    set blockage  [expr {[info exists curRegionBKG($region)] ? $curRegionBKG($region) : ""}]
    if {$extra_blockage ne ""} {
        set blockage [concat $blockage $extra_blockage]
    }
    set Die       [dbget top.fplan.box -e]

    P_VIA_GEN_MODE
    P_PG_GEN_MODE $layer

    addStripe \
        -area $Die \
        -area_blockage $blockage \
        -direction $direction \
        -layer $layer \
        -nets $nets \
        -start_offset $offset \
        -width $width \
        -spacing $spacing \
        -set_to_set_distance $pitch \
        -skip_via_on_wire_shape {} \
        -snap_wire_center_to_grid Grid \
        -uda PG_REPAIR
}

proc soc_add_sparse_pg_backbone {} {
    initializeRegionBKG
    createPowerStripe STD V M5 [list VDD 1] 7.560 0.080 0 30.240
    createPowerStripe STD V M5 [list VSS 1] 22.680 0.080 0 30.240
}

proc soc_add_sram_pg_hotspot_blockages {} {
    createRouteBlk -name sram_pg_m4_hotspot_mid  -layer {M4} -box {104.78 118.33 105.24 118.72}
    createRouteBlk -name sram_pg_m4_hotspot_high -layer {M4} -box {105.10 166.45 105.30 168.25}
    createRouteBlk -name sram_pg_m4_hotspot_low  -layer {M4} -box {61.84 61.58 62.24 67.20}
    createRouteBlk -name sram_pg_m3_hotspot_mid  -layer {M3} -box {105.00 118.34 105.18 118.54}
}

proc soc_route_pg {} {
    setSrouteMode -viaConnectToShape {ring stripe}
    sroute -nets {VDD VSS} -connect {corePin} \
      -corePinTarget {ring stripe} \
      -layerChangeRange {M1 M10} \
      -targetViaLayerRange {M1 M10} \
      -allowLayerChange 1 \
      -allowJogging 1
    sroute -nets {VDD VSS} -connect {blockPin} \
      -inst u_sram/u_sram_macro \
      -blockPinTarget {stripe ring} \
      -blockPinLayerRange {M4 M10} \
      -layerChangeRange {M4 M10} \
      -targetViaLayerRange {M4 M10} \
      -allowLayerChange 1 \
      -allowJogging 1
    if {!$::skip_floating_stripe} {
        sroute -nets {VDD VSS} -connect {floatingStripe} \
          -floatingStripeTarget {stripe ring} \
          -layerChangeRange {M1 M10} \
          -targetViaLayerRange {M1 M10} \
          -allowLayerChange 1
    }
}

proc soc_route_boundary_vpp_pgpins {} {
    setNanoRouteMode -routeAllowPowerGroundPin true
    catch {setAttribute -net VDD -skip_routing false}
    set trunk_ndr [dbGet head.rules.name TrunkNDR -e]
    catch {setPGPinUseSignalRoute TAPCELL*:VPP BOUNDARY_*TAP*:VPP}
    if {$trunk_ndr ne ""} {
        catch {
            setAttribute -net VDD \
                -avoid_detour true \
                -weight 20 \
                -non_default_rule TrunkNDR \
                -pattern trunk \
                -bottom_preferred_routing_layer 8 \
                -top_preferred_routing_layer 9
        }
        catch {routePGPinUseSignalRoute -maxFanout 1 -nonDefaultRule TrunkNDR}
    } else {
        catch {routePGPinUseSignalRoute -maxFanout 1}
    }
}

restoreDesign $route_enc soc_top
soc_refresh_pg_connectivity
soc_add_sram_pg_hotspot_blockages

set pre_drc [file join $pnr_out_dir drc_pre.rpt]
set pre_reg [file join $pnr_out_dir lvs_connectivity_regular_pre.rpt]
set pre_spc [file join $pnr_out_dir lvs_connectivity_special_pre.rpt]
verify_drc -limit 10000 -report $pre_drc
verifyConnectivity -type regular -error 1000 -warning 100 -report $pre_reg
verifyConnectivity -type special -noAntenna -error 2000 -warning 100 -report $pre_spc
puts "SPARSE_PG_BASELINE DRC=[parse_drc_violations $pre_drc] REG=[parse_connectivity_total $pre_reg] SPC=[parse_connectivity_total $pre_spc]"

soc_add_sparse_pg_backbone
soc_refresh_pg_connectivity
soc_route_pg
soc_refresh_pg_connectivity
soc_route_boundary_vpp_pgpins

set drc_rpt [file join $pnr_out_dir drc_final.rpt]
set reg_rpt [file join $pnr_out_dir lvs_connectivity_regular.rpt]
set spc_rpt [file join $pnr_out_dir lvs_connectivity_special.rpt]
verify_drc -limit 10000 -report $drc_rpt
verifyConnectivity -type regular -error 1000 -warning 100 -report $reg_rpt
verifyConnectivity -type special -noAntenna -error 2000 -warning 100 -report $spc_rpt

saveDesign [file join $pnr_out_dir with_sram_sparse_pgfix.enc]
puts "SPARSE_PG_SUMMARY DRC=[parse_drc_violations $drc_rpt] REG=[parse_connectivity_total $reg_rpt] SPC=[parse_connectivity_total $spc_rpt]"
exit
