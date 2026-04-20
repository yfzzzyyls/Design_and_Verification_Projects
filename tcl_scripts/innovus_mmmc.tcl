# Canonical MMMC setup for the known-good Innovus reference flow.
# This is the single repo MMMC file and matches the QRC-backed Calibre-clean run.

# Timing libraries (typ corner)
set std_lib   "/ip/tsmc/tsmc16adfp/stdcell/NLDM/N16ADFP_StdCelltt0p8v25c.lib"
set sram_lib  "/ip/tsmc/tsmc16adfp/sram/NLDM/N16ADFP_SRAM_tt0p8v0p8v25c_100a.lib"

# QRC technology file used by the reference DRC/LVS-clean design.
set qrc_tech  "/ip/tsmc/tsmc16adfp/tech/RC/N16ADFP_QRC/worst/qrcTechFile"

# Innovus may process the MMMC file from a temporary location during init, so
# anchor the project SDC to the launch directory rather than [info script].
set sdc_file [file normalize [file join [pwd] mapped_with_tech soc_top.sdc]]

# Create library set
create_library_set -name libset_typ -timing [list $std_lib $sram_lib]

# Create RC corner with QRC tech file.
create_rc_corner -name rc_typ \
                 -qx_tech_file $qrc_tech \
                 -temperature 25

# Create delay corner and analysis view
create_delay_corner -name dc_typ -library_set libset_typ -rc_corner rc_typ
create_constraint_mode -name mode_func -sdc_files [list $sdc_file]
create_analysis_view -name view_typ -constraint_mode mode_func -delay_corner dc_typ
set_analysis_view -setup {view_typ} -hold {view_typ}

puts ""
puts "=========================================="
puts "MMMC Setup with QRC Tech Files"
puts "=========================================="
puts "QRC Tech: $qrc_tech"
puts "Temperature: 25C"
puts "=========================================="
puts ""
