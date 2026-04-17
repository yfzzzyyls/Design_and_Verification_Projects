#!/usr/bin/env bash
set -euo pipefail

BASE="/tmp/v46_b17_wrapperfix.oas.gz"
LAYOUT="/tmp/v48_b17_master_complete.oas.gz"
TCL="/tmp/v48_b17_master_complete.tcl"
CMD="/tmp/v48_b17_master_complete.cmd"
REP="/tmp/v48_b17_master_complete.rep"
RULE_INC="/home/fy2243/soc_design/signoff/calibre_axi_uartcordic_currentrtl_postdrc_20260412_r2/05_drc/scr/drc.modified"

cat >"$TCL" <<'EOT'
set in_layout "/tmp/v46_b17_wrapperfix.oas.gz"
set out_layout "/tmp/v48_b17_master_complete.oas.gz"
set top [layout create $in_layout -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
set tc [$top topcell]
foreach layer {31.2 31.3 31.8 31.9 32.72 32.73 32.78 32.79 33.72 33.73 33.78 33.79} {
  catch {$top create layer $layer}
}

# Restore remaining empty B17 low-layer masters from the clean April 12 signoff layout.
foreach spec {
  {B17aDM2OH_CB 32.73 0 0 240 0 240 60 0 60}
  {B17aDM1OV_CA 31.2 0 0 60 0 60 240 0 240}
  {B17aDM1OV_CB 31.3 0 0 60 0 60 240 0 240}
  {B17aDM3OV_CA 33.72 0 0 60 0 60 240 0 240}
  {B17aDM3OV_CB 33.73 0 0 60 0 60 240 0 240}
  {B17aDM1S_CB 31.9 0 0 106 0 106 300 0 300}
  {B17aDM3S_CB 33.79 0 0 106 0 106 300 0 300}
  {B17aDM2S_CA 32.78 0 0 300 0 300 106 0 106}
  {B17aDM2S_CB 32.79 0 0 300 0 300 106 0 106}
  {B17aDM1B_CA 31.8 0 0 106 0 106 1160 0 1160}
  {B17aDM1B_CB 31.9 0 0 106 0 106 1160 0 1160}
  {B17aDM2B_CA 32.78 0 0 1160 0 1160 106 0 106}
  {B17aDM2B_CB 32.79 0 0 1160 0 1160 106 0 106}
  {B17aDM3B_CA 33.78 0 0 106 0 106 1160 0 1160}
  {B17aDM3B_CB 33.79 0 0 106 0 106 1160 0 1160}

  # Add the missing lower-layer polygons for the partially populated B17aFS_fs_1_5 master.
  {B17aFS_fs_1_5 32.78 3 0 1163 0 1163 106 3 106}
  {B17aFS_fs_1_5 32.78 3 424 1163 424 1163 530 3 530}
  {B17aFS_fs_1_5 32.78 3 848 1163 848 1163 954 3 954}
  {B17aFS_fs_1_5 31.8 0 3 106 3 106 1163 0 1163}
  {B17aFS_fs_1_5 31.8 424 3 530 3 530 1163 424 1163}
  {B17aFS_fs_1_5 31.8 848 3 954 3 954 1163 848 1163}
  {B17aFS_fs_1_5 32.79 3 212 1163 212 1163 318 3 318}
  {B17aFS_fs_1_5 32.79 3 636 1163 636 1163 742 3 742}
  {B17aFS_fs_1_5 32.79 3 1060 1163 1060 1163 1166 3 1166}
  {B17aFS_fs_1_5 31.9 212 3 318 3 318 1163 212 1163}
  {B17aFS_fs_1_5 31.9 636 3 742 3 742 1163 636 1163}
  {B17aFS_fs_1_5 31.9 1060 3 1166 3 1166 1163 1060 1163}
  {B17aFS_fs_1_5 33.78 0 3 106 3 106 1163 0 1163}
  {B17aFS_fs_1_5 33.78 424 3 530 3 530 1163 424 1163}
  {B17aFS_fs_1_5 33.78 848 3 954 3 954 1163 848 1163}
  {B17aFS_fs_1_5 33.79 212 3 318 3 318 1163 212 1163}
  {B17aFS_fs_1_5 33.79 636 3 742 3 742 1163 636 1163}
  {B17aFS_fs_1_5 33.79 1060 3 1166 3 1166 1163 1060 1163}
} {
  set cell [lindex $spec 0]
  set layer [lindex $spec 1]
  set coords [lrange $spec 2 end]
  catch {eval [concat [list $top create polygon $cell $layer] $coords]}
}

$top oasisout $out_layout $tc
exit
EOT

calibredrv -shell -s "$TCL" >/tmp/v48_b17_master_complete.layout.log 2>&1

cat >"$CMD" <<EOT
LAYOUT SYSTEM OASIS
LAYOUT PATH "$LAYOUT"
LAYOUT PRIMARY "soc_top"
DRC RESULTS DATABASE "/tmp/v48_b17_master_complete.db" ASCII
DRC SUMMARY REPORT "$REP" REPLACE HIER
VARIABLE VDD_TEXT "?VDD?"
include $RULE_INC
DRC SELECT CHECK M1.DN.1.T M2.DN.1.T M3.DN.1.T DM1.S.7 DM2.S.7 DM3.S.7 DM1.S.2 DM1.S.2.1 DM1.S.2.2 DM2.S.2 DM2.S.2.1 DM2.S.2.2 DM3.S.2 DM3.S.2.1 DM3.S.2.2
EOT

calibre -drc "$CMD" >/tmp/v48_b17_master_complete.log 2>&1

for r in 'M1.DN.1.T' 'M2.DN.1.T' 'M3.DN.1.T' 'DM1.S.7' 'DM2.S.7' 'DM3.S.7' 'DM1.S.2 ' 'DM1.S.2.2' 'DM2.S.2 ' 'DM2.S.2.2' 'DM3.S.2 ' 'DM3.S.2.2'; do
  grep "RULECHECK $r" "$REP"
done
