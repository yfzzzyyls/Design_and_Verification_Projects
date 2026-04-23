VARIABLE POWER_NAME "VDD" "VDDPST" "AVDD" "DVDD"
VARIABLE GROUND_NAME "VSS"
LAYOUT PRIMARY "soc_top"
LAYOUT PATH "./output/soc_top.boundary_ap_via3onecut_cts2swap.supplyalias.global.notopports.layspi"
LAYOUT SYSTEM SPICE
SOURCE PRIMARY "soc_top"
SOURCE PATH "./source_fix/soc_top_lvs.spi"
ERC RESULTS DATABASE "output/calibre_erc_boundary_ap_via3onecut_cts2swap_supplyalias_global_notopports.db" ASCII
ERC SUMMARY REPORT "output/calibre_erc_boundary_ap_via3onecut_cts2swap_supplyalias_global_notopports.sum"
LVS REPORT "output/lvs_boundary_ap_via3onecut_cts2swap_supplyalias_global_notopports.rep"
include ./source_fix/hcell_boxes.inc
include ./source_fix/ignore_device_pins.inc
include ./source_fix/exclude_cells.inc
include ./source_fix/exclude_layout_wrappers.inc
include ./scr/lvs.modified
LVS CELL SUPPLY YES
LVS GLOBALS ARE PORTS NO
LVS NETLIST BOX CONTENTS YES
LVS NETLIST UNNAMED BOX PINS YES
LVS BLACK BOX PORT M1 M1_text M1
LVS BLACK BOX PORT M2 M2_text M2
LVS BLACK BOX PORT M3 M3_text M3
LVS BLACK BOX PORT M4 M4_text M4
