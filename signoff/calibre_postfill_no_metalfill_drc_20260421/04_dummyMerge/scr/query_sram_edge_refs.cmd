set top [layout create "./output/soc_top.dmmerge.oas.gz" -dt_expand -preservePaths -preserveTextAttributes -preserveProperties]
set topCell [$top topcell]

set llx 104800
set lly 62000
set urx 106000
set ury 168000

set refs [$top query ref $topCell 0 3 $llx $lly $urx $ury -all -list]
puts "refs near SRAM right edge: [llength $refs]"
foreach ref $refs {
    if {[llength $ref] < 11} {
        puts "SHORT_REF $ref"
        continue
    }
    set bbox_x [lindex $ref 0]
    set bbox_y [lindex $ref 1]
    set bbox_w [lindex $ref 2]
    set bbox_h [lindex $ref 3]
    set refcell [lindex $ref 4]
    set x [lindex $ref 5]
    set y [lindex $ref 6]
    set mirror [lindex $ref 7]
    set angle [lindex $ref 8]
    set mag [lindex $ref 9]
    set props [lindex $ref 10]
    puts "REF cell=$refcell bbox=($bbox_x,$bbox_y,[expr {$bbox_x+$bbox_w}],[expr {$bbox_y+$bbox_h}]) place=($x,$y,$mirror,$angle,$mag) props=$props"
}
exit
