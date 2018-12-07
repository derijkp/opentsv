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
Short description
-----------------
When opening a comma or tab separated value file, Excel converts any
data that looks like a date or a number to an internal (different) format, 
causing big problems when text data such as gene names (e.g. SEPT2),
identifiers (1-2), ... are converted to Excel dates. 
This program opens tab-separated (tsv) or comma-separated (csv) files in
Excel without this conversion/corruption of data.

Use
---
Starting the program without a file gives you this settings/installation
screen. This program does not have to be installed though: You can use it
directly by using the "Open file" or by dragging a file onto the exe.
However, if you install it and/or register it as the default program to
open tsv and csv files (bottom), its use becomes transparent: double
clicking a tsv file will open it in Excel with the current settings.

In this settings screen you can also change the way opentsv handles
separators and conversion methods used: from importing everything as text
to opening the file in the default Excel style.

Longer description
------------------
Opentsv first scans a given file to detect the separator. It then opens
Excel and forces it to load the file using the selected method, e.g.
importing all columns as text, thus protecting your data from conversion.
A file opened this way will be (by default) saved as a tab-separated file,
even if the orignal was comma separated. If you need to save it as
comma-separated, use "save as".

Opentsv will also solve the problem that for users in some locales using a
decimal comma, Excel assumes a semicolon as the delimiter for csv files
(contrary to rfc4180) and refuses to load properly formatted csv files
(without changing the locale).

For opening csv files properly, a hack was needed: The parameters used for
opening files with the extension .csv seem to be hard-coded in Excel: It
does not honor any adapted parameters for conversion or separater if it
has the extension csv. Therefore opentsv copies a .csv file first to a
.tcsv file and opens that one instead.

Copyright (c) 2017 Peter De Rijk (VIB - University of Antwerp)
Available under MIT license
}

if {![info exists debug]} {
	set debug 0
}

if {$tcl_platform(platform) ne "unix"} {
	package require tcom
}

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

proc programfilesdir {} {
	if {$::tcl_platform(platform) eq "unix"} {
		# for testing
		return {}
	}
	registry get HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion ProgramFilesDir
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
	set programfilesdir [programfilesdir]
	set installdir $programfilesdir
	destroy .installd
	toplevel .installd
	wm title .installd Install
	label .installd.info -text {Installation is not really required for this program
It is a single executable that can also be run in place.
This "installation" will copy the executable into the installation folder
and make the proper links to make it run automatically from the installation directory when double clicking.}
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

proc settings {what {value {}}} {
	if {[info exists ::env(APPDATA)]} {
		set inifile [file join $::env(APPDATA)/opentsv.conf]
	} else {
		set inifile [file join $::env(HOME)/opentsv.conf]
	}
	if {[file exists $inifile]} {
		set f [open $inifile]
		set settings [gets $f]
		close $f
	} else {
		set settings {numeric allwaysauto 1}
	}
	if {[llength $settings] == 1} {lappend settings auto}
	if {[llength $settings] == 2} {lappend settings 1}
	set pos [lsearch {method sepmethod copycsv} $what]
	if {$value eq ""} {
		return [lindex $settings $pos]
	} else {
		set settings [lreplace $settings $pos $pos $value]
		set o [open $inifile w]
		puts $o $settings
		close $o
		return $settings
	}
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
	} elseif {$type eq "semicolon"} {
		return [csv_split $line \;]
	} elseif {$type eq "space"} {
		return [csv_split $line " "]
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
	global application tcl_platform
	if {$tcl_platform(platform) ne "unix"} {
		if {![info exists application]} {
			set application [::tcom::ref createobject "Excel.Application"]
		}
		$application Visible 1
		set workbooks [$application Workbooks]
	}
	set method [settings method]
	set sepmethod [settings sepmethod]
	set copycsv [settings copycsv]
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
	# determine separator
	set type {}
	if {[file extension $file] eq ".csv"} {
		if {$method ne "excel" && $copycsv} {
			set tempfile [file root $file].tcsv
			set num 0
			while {[file exists $tempfile]} {
				set tempfile [file root $file][incr num].tcsv
			}
			file copy $file $tempfile
			set file $tempfile
		}
		if {$sepmethod eq "auto"} {
			set type comma
		}
	} elseif {[file extension $file] eq ".tsv"} {
		if {$sepmethod eq "auto"} {
			set type tab
		}
	}
	# analyse file
	set f [open $file]
	# skip comments
	while {[gets $f line] != -1 && [string index $line 0] eq "\#"} {}
	# get maximum amount of columns in csv
	set count 0
	# if there are commas in some of the fields, we only get a higher number, which is not a problem
	if {$sepmethod in "comma tab semicolon space"} {
		set type $sepmethod
	} elseif {$type eq ""} {
		set tempcount [llength [split $line ,]]
		if {$tempcount > $count} {set count $tempcount; set type comma}
		set tempcount [llength [split $line \t]]
		if {$tempcount > $count} {set count $tempcount; set type tab}
		set tempcount [llength [split $line \;]]
		if {$tempcount > $count} {set count $tempcount; set type semicolon}
		if {$count == 1} {
			# space may occur a lot in the values, only try space if the others are not present
			set tempcount [llength [split $line " "]]
			if {$tempcount > $count} {set count $tempcount; set type space}
		}
	}
	set line [splitline $line $type]
	set count [llength $line]
	# first line may be a header; use second line, unless it is empty/does not exist
	set dataline [splitline [gets $f] $type]
	if {![llength $dataline]} {set dataline $line}
	if {$method eq "numeric"} {
		# check the first line to look for numbers
		# numa($pos) contains 1 if the col is numeric, 2 if empty:
		# numeric columns may contain empty values, but 
		# if all tested values are empty, we will not call it numberic
		unset -nocomplain numa
		set pos 1
		foreach el $dataline {
			if {[string is double $el]} {
				if {$el eq ""} {
					set numa($pos) 2
				} else {
					set numa($pos) 1
				}
			}
			incr pos
		}
		set curpos 1
		set poss [array names numa]
		while {[gets $f line] != -1} {
			incr curpos ; if {$curpos > 10} break
			set dataline [splitline $line $type]
			set pos 1
			foreach el $dataline {
				if {![string is double $el]} {
					unset -nocomplain numa($pos)
				} elseif {$el ne ""} {
					set numa($pos) 1
				}
				incr pos
			}
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
		set tab $TRUE ; set comma $FALSE ; set semicolon $FALSE ; set space $FALSE
	} elseif {$type eq "comma"} {
		set tab $FALSE ; set comma $TRUE ; set semicolon $FALSE ; set space $FALSE
	} elseif {$type eq "semicolon"} {
		set tab $FALSE ; set comma $FALSE ; set semicolon $TRUE ; set space $FALSE
	} else {
		set tab $FALSE ; set comma $FALSE ; set semicolon $FALSE ; set space $TRUE
	}
	if {$tcl_platform(platform) eq "unix"} {
		# testing
		puts [list workbooks -namedarg OpenText Filename [file normalize $file] \
			DataType $xlDelimited \
			Comma $comma Tab $tab Semicolon $semicolon Space $space\
			TextQualifier $xlTextQualifierDoubleQuote \
			FieldInfo $fieldinfo]
	} else {
		$workbooks -namedarg OpenText Filename [file normalize $file] \
			DataType $xlDelimited \
			Comma $comma Tab $tab Semicolon $semicolon Space $space \
			TextQualifier $xlTextQualifierDoubleQuote \
			FieldInfo $fieldinfo
	}
}

proc interface {} {
	global workbooks debug
	set ::method [settings method]
	set ::sepmethod [settings sepmethod]
	set ::copycsv [settings copycsv]
	# interface if no file is give
	package require Tk
	wm title . Opentsv

	destroy .open .settings .b .msglabel .msg
	. configure -padx 4 -pady 4
	#
	# help
	label .msglabel -text "Opentsv description"
	pack .msglabel -side top -fill x
	frame .msg
	text .msg.t -yscrollcommand {.msg.s set} -height 15
	.msg.t insert end [string trim $::help]
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
	label .settingslabel -text "Settings" -font TkHeadingFont
	bind .settingslabel <2> {console show}
	pack .settingslabel -side top -fill x
	frame .settings
	pack .settings -side top -fill x
	label .settings.method -text "Method"
	pack .settings.method -side left -anchor n
	foreach {name descr ldescr} {
		all "All as text" "No conversion will happen because everything is imported as text"
		numeric "Only convert numerical columns" "Conversion can happen for columns containing only numbers (first 10 lines checked)"
		convall "Convert all" "All columns may be converted by Excel"
		excel "Excel default" "Open data files using Excel without intervention of opentsv"
	} {
		radiobutton .settings.$name -text "$descr: $ldescr" \
			-variable method -value $name \
			-command [list settings method $name]
		pack .settings.$name -side top -fill y -anchor w
	}
	frame .settings2
	pack .settings2 -side top -fill x
	label .settings2.method -text "Separator"
	pack .settings2.method -side left -anchor n
	foreach {name descr ldescr} {
		allwaysauto "Allways autodetect" "opentsv detects the delimiter from the data,"
		auto "Autodetect (not csv and tsv)" "autodetect except for csv and tsv files (allways comma and tab respectively)"
		comma "comma" "Always use comma as delimiter"
		tab "tab" "Always use tab as delimiter"
		semicolon "semicolon" "Always use semicolon as delimiter"
		space "space" "Always use space as delimiter"
	} {
		radiobutton .settings2.$name -text "$descr: $ldescr" \
			-variable sepmethod -value $name \
			-command [list settings sepmethod $name]
		pack .settings2.$name -side top -fill y -anchor w
	}
#	checkbutton .copycsv -justify left -anchor w -text "Locale hack: Copy csv to tcsv first (so it can be opened using commas in locales using an other delimiter)" \
#		-variable copycsv \
#		-command "settings copycsv \$::copycsv"
#	pack .copycsv -side top -fill x
	#
	# install
	label .installlabel -text "Install" -font TkHeadingFont
	pack .installlabel -side top -fill x
	label .installdescr -text "Opentsv is a single file executable that can be used without installation.
It is more useful if registered to automatically open delimited file types (on double click)
The \"Install\" will copy it to an installation folder and register this copy." -justify left
	pack .installdescr -side top -fill x -anchor w
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
	set programfilesdir [programfilesdir]
	if {[file normalize [info nameofexecutable]] ne [file normalize $programfilesdir/opentsv/opentsv.exe]} {
		button .b.install -command install -text Install
		pack .b.install -side left
	}
	# exit
	button .b.exit -command exit -text Exit
	pack .b.exit

	if {!$debug} {
		tkwait window .
		exit
	}
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

if {!$debug} {
	exit
}
