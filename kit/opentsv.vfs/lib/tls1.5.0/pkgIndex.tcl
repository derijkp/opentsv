# pkgIndex.tcl - 
#
#    A new manually generated "pkgIndex.tcl" file for tls to
#    replace the original which didn't include the commands from "tls.tcl".
#
#    NB: Requires 8.3 preferably (perhaps definately) 8.3.2+
#    Tested with 8.3.3 and 8.4+ [PT]

if {![package vsatisfies [package provide Tcl] 8.3]} {return}
package ifneeded tls 1.5 "[list load [file join $dir tls15.dll] ] ; [list source [file join $dir tls.tcl] ]"

