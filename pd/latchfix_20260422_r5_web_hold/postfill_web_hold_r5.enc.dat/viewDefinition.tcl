if {![namespace exists ::IMEX]} { namespace eval ::IMEX {} }
set ::IMEX::dataVar [file dirname [file normalize [info script]]]
set ::IMEX::libVar ${::IMEX::dataVar}/libs

create_library_set -name libset_typ\
   -timing\
    [list ${::IMEX::libVar}/mmmc/N16ADFP_StdCelltt0p8v25c.lib\
    ${::IMEX::libVar}/mmmc/N16ADFP_SRAM_tt0p8v0p8v25c_100a.lib]
create_rc_corner -name rc_typ\
   -preRoute_res 1\
   -postRoute_res 1\
   -preRoute_cap 1\
   -postRoute_cap 1\
   -postRoute_xcap 1\
   -preRoute_clkres 0\
   -preRoute_clkcap 0\
   -qx_tech_file ${::IMEX::libVar}/mmmc/rc_typ/qrcTechFile
create_delay_corner -name dc_typ\
   -library_set libset_typ\
   -rc_corner rc_typ
create_constraint_mode -name mode_func\
   -sdc_files\
    [list ${::IMEX::dataVar}/mmmc/modes/mode_func/mode_func.sdc]
create_analysis_view -name view_typ -constraint_mode mode_func -delay_corner dc_typ -latency_file ${::IMEX::dataVar}/mmmc/views/view_typ/latency.sdc
set_analysis_view -setup [list view_typ] -hold [list view_typ]
