package require starkit
starkit::startup
#console show

#!/bin/sh
# the next line restarts using wish \
exec wish "$0" ${1+"$@"}
# ClassyTk Builder v0.2

set script [info script]
set basedir [file dir $script]
lappend auto_path $basedir/lib
source $basedir/opentsv.tcl

