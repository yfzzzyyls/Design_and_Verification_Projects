##########################################################################################
# User-defined variables for logical library setup in dc_setup.tcl
##########################################################################################

set PDK_DIR "/ip/synopsys/saed32/v02_2024" ; #  Path to the PDK directory

set ADDITIONAL_SEARCH_PATH   "$PDK_DIR/lib/stdcell_hvt/db_nldm $PDK_DIR/tech/tf $PDK_DIR/tech/starrc/max $PDK_DIR/tech/starrc $PDK_DIR/temporary_ndm ./rtl ./scripts"  ;#  Directories containing logic libraries,
                                                                                       #  logic design and script files.

set TARGET_LIBRARY_FILES     "saed32hvt_ss0p75v125c.db"                              ;#  Logic cell library files

##########################################################################################
# User-defined variables for physical library setup in dc_setup.tcl
##########################################################################################

set NDM_DESIGN_LIB           "TOP.dlib"                 ;#  User-defined NDM design library name

set NDM_REFERENCE_LIBS       "saed32_hvt.ndm"                 ;#  NDM physical cell libraries

set TECH_FILE                "saed32nm_1p9m.tf"              ;#  Technology file

set TLUPLUS_MAX_FILE         "saed32nm_1p9m_Cmax.tluplus"    ;#  Max TLUPlus file

set MAP_FILE                 "saed32nm_tf_itf_tluplus.map"   ;#  Mapping file for TLUplus

return
