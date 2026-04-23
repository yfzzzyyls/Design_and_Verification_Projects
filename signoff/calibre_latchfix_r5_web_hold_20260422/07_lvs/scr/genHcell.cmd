source ./scr/var.tcl
foreach lef $lefList {
    set cellList [exec grep "MACRO " $lef | awk {{print $2}}]
    foreach cell $cellList {
        puts "$cell $cell"
    }
}
