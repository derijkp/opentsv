#!/bin/sh
# the next line restarts using wish \
exec tclsh "$0" ${1+"$@"}

# Copyright (c) 2017 Peter De Rijk (VIB - University of Antwerp)
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

set help {
Opentsv
=======
Open tsv or csv files in Excel without converting all data that looks like a
date to an internal (different) format.

Description
-----------
When opening a comma or tab separated value file, Excel converts any
data that looks like a date to an internal (different) format, 
causing big problems when text data such as gene names (e.g. SEPT2),
identifiers (1-2), ... are converted to Excel dates. This could only 
be stopped by going through the text import wizard and setting all 
columns to Text. This program will open a csv/tsv file in Excel, 
using text format (or other options) for all columns, thus protecting 
your data from conversion. A file opened this way will be (by default) 
saved as a tab-separated file, even if the orignal was comma separated.

Because Excel cannot be convinced to mend its evil ways if a file has 
the csv extension, a copy with the extension tcsv is made first and 
then opened. Opentsv will recognize commas (and only commas) as 
separaters in a csv file (as per rfc4180), unlike Excel: It 
will a different separator, e.g. a semicolon, depending on the 
locale (making it difficult to easily open actual csv files). However, 
if the "Excel default" option is chosen, opentsv will let Excel open 
files in its usual fashion.

Use
---
You can drag one or more files onto the program, or set it as a default
program to open tsv and csv files. If you start the program without a
file as parameter, you get in the settings dialog. Here you can select 
the method used: from importing everything as text to opening the file
in the default Excel style. There are also buttons to register opentsv 
as default program for several extensions.

Copyright (c) 2017 Peter De Rijk (VIB - University of Antwerp)
Available under MIT license
}

package require tcom

proc register_filetype {extension class name mime code {icon {}}} {
	package require registry
	set error 1
	foreach hkey {HKEY_CLASSES_ROOT HKEY_CURRENT_USER\\Software\\Classes} {
		if {![catch {
			set extPath $hkey\\$extension
			set classPath $hkey\\$class
			set shellPath $classPath\\Shell
			registry set $extPath {} $class sz
			registry set $classPath {} $name sz
			registry set $shellPath\\open\\command {} $code sz
			# mimetype
			registry set $extPath "Content Type" $mime sz
			set mimeDbPath "$hkey\\MIME\\Database\\Content Type\\$mime"
			registry set $mimeDbPath Extension $extension sz
			if {[llength $icon]} {
				if {[llength $icon] != 2} {
					error "icon should be a list of {filename number}"
				}
				foreach {file number} $icon break
				registry set $classPath\\DefaultIcon {} [file nativename $file],$number sz
			}
		}]} {set error 0}
	}
	if {$error} {error $::errorInfo}
}

proc fileassoc {executable} {
	if {$executable eq ""} {set executable [info nameofexecutable]}
	foreach {ext mime name} {
		csv "text/comma-separated-values" "Comma-Separated Value file"
		tsv "text/tab-separated-values" "Tab-Separated Value file"
		tcsv "text/tab-separated-values" "Tab-Separated Value file"
		tab "text/tab-separated-values" "Tab-Separated Value file"
	} {
		if {$::reg($ext)} {
			register_filetype .$ext ${ext}file $name $mime "\"[file nativename $executable]\" \"%1\""
		}
	}
}

proc install {} {
	global installdir install env
	set programfilesdir [registry get HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion ProgramFilesDir]
	set installdir $programfilesdir
	destroy .installd
	toplevel .installd
	wm title .installd Install
	label .installd.info -text {This program does not have to be installed;
It is a single executable that can also be run in place.
This "installation" will only copy the executable into the installation folder
and make the proper links.}
	pack .installd.info -side top -fill x
	frame .installd.browse
	pack .installd.browse -side top -fill x -expand yes
	entry .installd.browse.dir -textvariable installdir
	pack .installd.browse.dir -side left -fill x -expand yes
	button .installd.browse.browse -text Browse -command {set ::installdir [tk_chooseDirectory -initialdir $::installdir]}
	pack .installd.browse.browse -side left
	frame .installd.buttons
	pack .installd.buttons -side top -fill x
	button .installd.buttons.installd -text Install -command {set install 1 ; destroy .installd}
	button .installd.buttons.cancel -text Cancel -command {set install 0 ; destroy .installd}
	pack .installd.buttons.installd -side left -expand yes -pady 4
	pack .installd.buttons.cancel -side left -expand yes -pady 4
	raise .installd
	tkwait window .installd
	if {!$install} return
	#
	destroy .install
	label .install
	pack .install -side top -fill y
	package require registry
	package require dde
	set source [info nameofexecutable]
	set dest [file join $installdir [file tail $source]]
	set text "Installing to $dest"
	.install configure -text $text ; update idletasks
	file delete $dest
	exec cmd.exe /c copy [file nativename $source] [file nativename $dest]
	#
	append text "\nAssociating files" ; .install configure -text $text ; update idletasks
	set executable [file normalize $dest]
	set name [file tail [file root $executable]]
	fileassoc $executable
	#
	append text "\nAdding to menu" ; .install configure -text $text ; update idletasks
	catch {dde execute progman progman "\[DeleteGroup (OPENTSV)\]"}
	catch {dde execute progman progman "\[CreateGroup (OPENTSV)\]"}
	catch {dde execute progman progman "\[AddItem (\"[file nativename $executable]\",$name,\"\",0,0,0,$env(HOME))\]"}
	append text "\nFinished" ; .install configure -text $text ; update idletasks
}

proc method {{method {}}} {
	if {[info exists ::env(APPDATA)]} {
		set inifile [file join $::env(APPDATA)/opentsv.conf]
	} else {
		set inifile [file join $::env(HOME)/opentsv.conf]
	}
	if {$method eq ""} {
		if {[file exists $inifile]} {
			set f [open $inifile]
			set method [gets $f]
			close $f
		} else {
			set method numeric
		}
	} else {
		set o [open $inifile w]
		puts $o $method
		close $o
	}
	return $method
}

set method [method]

proc interface {} {
	global workbooks
	# interface if no file is give
	package require Tk
	wm title . Opentsv

	destroy .settings .b .msglabel .msg
	. configure -padx 4 -pady 4
	#
	# help
	label .msglabel -text "Opentsv description"
	pack .msglabel -side top -fill x
	frame .msg
	text .msg.t -yscrollcommand {.msg.s set} -height 20
	.msg.t insert end $::help
	scrollbar .msg.s -command {.msg.t yview}
	pack .msg.t -side left -fill both -expand yes
	pack .msg.s -side left -fill y
	pack .msg -side top -fill both -expand yes
	#
	# open file
	frame .open
	button .open.open -text "Open file" -command {
		foreach file [tk_getOpenFile -multiple 1] {
			opentsv $file
		}
	}
	pack .open.open -side top -fill x
	pack .open -side top -fill x
	#
	# settings
	frame .settings
	pack .settings -side top -fill x -expand yes
	label .settings.method -text "Method"
	pack .settings.method -side left
	foreach {name descr} {
		all "All as text"
		numeric "Only convert numerical columns"
		convall "Convert everything"
		excel "Excel default"
	} {
		radiobutton .settings.$name -text $descr \
			-variable method -value $name \
			-command [list method $name]
		pack .settings.$name -side left
	}
	#
	# buttons
	frame .b
	pack .b -side top -fill x
	set executable [info nameofexecutable]
	button .b.filel \
		-text "Register opentsv as default program for opening" \
		-command [list fileassoc $executable]
	pack .b.filel -side left
	foreach {ext} {csv tsv tab tcsv} {
		checkbutton .b.$ext -text $ext -variable reg($ext)
		set ::reg($ext) 1
		pack .b.$ext -side left
	}
	# install
	set programfilesdir [registry get HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion ProgramFilesDir]
	if {[file normalize [info nameofexecutable]] ne [file normalize $programfilesdir/opentsv/opentsv.exe]} {
		button .b.install -command install -text Install
		pack .b.install -side left
	}
	# exit
	button .b.exit -command exit -text Exit
	pack .b.exit

	tkwait window .
	exit
}

proc csv_split {line sep} {
        set resultline {}
        set quotereplace {{""} {"}}
        set quoteconnect $sep
        set line [split $line $sep]
        foreach el $line {
                if {![info exists quotedstring]} {
                        if {[string equal [string index $el 0] \"]} {
                                # check if the el is the proper ending of a quoted string
                                if {[string equal $el \"\"] || [regexp {([^"]|\A)("")*"$} $el]} {
                                        lappend resultline [string map $quotereplace [string range $el 1 end-1]]
                                } else {
                                        set quotedstring [string range $el 1 end]
                                }
                        } else {
                                lappend resultline $el
                        }
                } else {
                        if {[regexp {([^"]|\A)("")*"$} $el]} {
                                append quotedstring $quoteconnect[string range $el 0 end-1]
                                set quotedstring [string map $quotereplace $quotedstring]
                                lappend resultline $quotedstring
                                unset quotedstring
                        } else {
                                append quotedstring $quoteconnect$el
                        }
                        set quoteconnect $sep
                }
        }
        return $resultline
}

proc splitline {line type} {
	if {$type eq "comma"} {
		return [csv_split $line ,]
	} else {
		return [split $line \t]
	}
}

proc openexcel {} {
	set application [::tcom::ref createobject "Excel.Application"]
	$application Visible 1
	return [$application Workbooks]
}

# open files
proc opentsv {file} {
	global application
	if {![info exists application]} {
		set application [::tcom::ref createobject "Excel.Application"]
	}
	$application Visible 1
	set workbooks [$application Workbooks]
	set method [method]
	set TRUE 1
	set FALSE 0
	if {$TRUE} {}
	if {$FALSE} {}
	# enumerations from https://msdn.microsoft.com/en-us/VBA/Excel-VBA/articles/enumerations-excel
	set xlDelimited	[expr 1]
	set xlTextQualifierDoubleQuote [expr 1]
	set xlGeneralFormat	[expr 1]
	set xlTextFormat [expr 2]
	set xlWindows	[expr 2]
	#
	if {$method eq "excel"} {
		$workbooks -namedarg Open Filename [file normalize $file]
		return
	}
	if {[file extension $file] eq ".csv"} {
		if {$method ne "excel"} {
			set tempfile [file root $file].tcsv
			set num 0
			while {[file exists $tempfile]} {
				set tempfile [file root $file][incr num].tcsv
			}
			file copy $file $tempfile
			set file $tempfile
		}
		set type comma
	} elseif {[file extension $file] eq ".tsv"} {
		set type tab
	} else {
		set type {}
	}
	# analyse file
	set f [open $file]
	# skip comments
	while {[gets $f line] != -1 && [string index $line 0] eq "\#"} {}
	# get maximum amount of columns in csv
	set count 0
	# if there are commas in some of the fields, we only get a higher number, which is not a problem
	if {$type eq ""} {
		set tempcount [llength [split $line ,]]
		if {$tempcount > $count} {set count $tempcount; set type comma}
		set tempcount [llength [split $line \t]]
		if {$tempcount > $count} {set count $tempcount; set type tab}
	}
	set line [splitline $line $type]
	set count [llength $line]
	# first line may be a header; use second line, unless it is empty/does not exist
	set dataline [splitline [gets $f] $type]
	if {![llength $dataline]} {set dataline $line}
	if {$method eq "numeric"} {
		# check the first line to look for numbers
		set pos 1
		foreach el $dataline {
			if {[string is double $el]} {set numa($pos) 1}
			incr pos
		}
	}
	close $f
	
	# create (text) formatting array
	set fieldinfo {}
	incr count
	for {set i 1} {$i < $count} {incr i} {
		if {$method eq "convall" || [info exists numa($i)]} {
			lappend fieldinfo [list $i $xlGeneralFormat]
		} else {
			lappend fieldinfo [list $i $xlTextFormat]
		}
	}
	if {$type eq "tab"} {
		set tab $TRUE ; set comma $FALSE
	} else {
		set tab $FALSE ; set comma $TRUE
	}
	$workbooks -namedarg OpenText Filename [file normalize $file] \
		DataType $xlDelimited \
		Comma $comma Tab $tab Semicolon $FALSE \
		TextQualifier $xlTextQualifierDoubleQuote \
		FieldInfo $fieldinfo
}

if {![llength $argv]} {
	interface
} else {
	foreach file $argv {
		opentsv $file
	}
}

#package require Tk
#tk_messageBox -title "test" -detail [list method: $method argv0: $argv0 argv: $argv]

exit
