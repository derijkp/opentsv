package require Extral
catch {tk appname test}

package require pkgtools
namespace import -force pkgtools::*
package require Extral

set test_cleantmp 1

proc test {args} {
	if {[get ::test_cleantmp 1]} {test_cleantmp}
	catch {job_init}
	pkgtools::test {*}$args
	cd $::testdir
	return {}
}

proc pathsep {} {
	if {$::tcl_platform(platform) eq "windows"} {return \;} else {return \:}
}

# pkgtools::testleak 100

set keeppath $::env(PATH)
set script [info script] ; if {$script eq ""} {set script ./t}
set testdir [file dir [file normalize $script]]
set appdir [file dir [file dir [file normalize $script]]]
set debug 1
source $appdir/opentsv.tcl
append ::env(PATH) [pathsep]$appdir/bin
# putsvars ::env(PATH)
set env(SCRATCHDIR) [file dir [tempdir]]

proc test_cleantmp {} {
	foreach file [list_remove [glob -nocomplain $::testdir/tmp/* $::testdir/tmp/.*] $::testdir/tmp/.. $::testdir/tmp/.] {
		catch {file attributes $file -permissions ugo+xw}
		catch {file delete -force $file}
	}
}

# remove tmp if it is a unexisting link
if {![file exists tmp]} {catch {file delete tmp}}
file mkdir tmp
set dbopt {}
set dboptt {}
