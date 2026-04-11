VARIABLE POWER_NAME "VDD" "VDDM" "VDDPST" "AVDD" "DVDD"
VARIABLE GROUND_NAME "VSS"
LAYOUT PRIMARY "soc_top"
LAYOUT PATH "../04_dummyMerge/output/soc_top.dmmerge_macroedge_cut1plus.oas.gz"
LAYOUT SYSTEM OASIS
SOURCE PRIMARY "soc_top"
SOURCE PATH "../06_v2lvs/soc_top_extract.spi"
ERC RESULTS DATABASE "output/calibre_erc.db" ASCII
ERC SUMMARY REPORT "output/calibre_erc.sum"
LVS REPORT "output/lvs.rep"
include ./rpt/hcell_boxes.inc
include ./scr/lvs.modified
LVS NETLIST BOX CONTENTS YES
LVS NETLIST UNNAMED BOX PINS YES
LVS BLACK BOX PORT M1 M1_text M1
LVS BLACK BOX PORT M2 M2_text M2
LVS BLACK BOX PORT M3 M3_text M3
LVS BLACK BOX PORT M4 M4_text M4
