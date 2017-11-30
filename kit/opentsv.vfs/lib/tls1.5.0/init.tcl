
# pkgIndex.tcl - 
#
#    A new manually generated "pkgIndex.tcl" file for tls to
#    replace the original which didn't include the commands from "tls.tcl".
#

load [lindex [glob [file join $dir *tls*[info sharedlibextension]]] 0]
source [file join $dir tls.tcl]
extension provide tls 1.5.0
