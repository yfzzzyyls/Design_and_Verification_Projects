source ./scr/var.tcl
foreach spi $spiList {
    puts ".INCLUDE $spi"
}
