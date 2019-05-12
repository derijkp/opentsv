#!/bin/sh
# the next line restarts using wish \
exec tclsh "$0" "$@"

source tools.tcl

settings method numeric
settings sepmethod allwaysauto

test opentsv {issafenum} {
	list [issafenum 0] [issafenum 0.1] [issafenum 10] [issafenum 1.10] [issafenum 0] [issafenum 0] \
		[issafenum e1] [issafenum a] [issafenum 1,1] [issafenum 1x1]
} {1 1 1 1 1 1 0 0 0 0}

test opentsv {data.tsv} {
	exec ../opentsv.tcl data/data.tsv
} {workbooks -namedarg OpenText Filename */data.tsv DataType 1 Comma 0 Tab 1 Semicolon 0 Space 0 TextQualifier 1 FieldInfo {{1 2} {2 2} {3 2} {4 1} {5 1} {6 1}}} match

test opentsv {problems.tsv} {
	exec ../opentsv.tcl data/problems.tsv
} {workbooks -namedarg OpenText Filename */problems.tsv DataType 1 Comma 0 Tab 1 Semicolon 0 Space 0 TextQualifier 1 FieldInfo {{1 2} {2 2}}} match

test opentsv {emptyline} {
	file_write tmp/test.tsv [deindent {
		# comment
		
		a	1
		b	2
	}]\n
	exec ../opentsv.tcl tmp/test.tsv
} {workbooks -namedarg OpenText Filename */test.tsv DataType 1 Comma 0 Tab 1 Semicolon 0 Space 0 TextQualifier 1 FieldInfo {{1 2} {2 1}}} match

test opentsv {emptyline} {
	file_write tmp/test.tsv [deindent {
		# comment
		
		a	1
		b	2
	}]\n
	set method numeric ; set sepmethod allwaysauto ; set type {}
	set result {}
	foreach method {numeric all convall} {
		lappend result [analyse_file tmp/test.tsv $method $sepmethod $type]
	}
	join $result \n
} {tab {{1 2} {2 1}}
tab {{1 2} {2 2}}
tab {{1 1} {2 1}}}

test opentsv {emptyline} {
	file_write tmp/test.tsv [deindent {
		a	1
		b	2e0
	}]\n
	set method numeric ; set sepmethod allwaysauto ; set type {}
	set result {}
	foreach method {numeric all convall} {
		lappend result [analyse_file tmp/test.tsv $method $sepmethod $type]
	}
	join $result \n
} {tab {{1 2} {2 2}}
tab {{1 2} {2 2}}
tab {{1 1} {2 1}}}

test analyse_file {data.tsv} {
	set method numeric ; set sepmethod allwaysauto ; set type {}
	analyse_file data/data.tsv $method $sepmethod $type
} {tab {{1 2} {2 2} {3 2} {4 1} {5 1} {6 1}}}

test analyse_file {data.tsv} {
	set method all ; set sepmethod allwaysauto ; set type {}
	analyse_file data/data.tsv $method $sepmethod $type
} {tab {{1 2} {2 2} {3 2} {4 2} {5 2} {6 2}}}

test analyse_file {data.tsv} {
	set method convall ; set sepmethod allwaysauto ; set type {}
	analyse_file data/data.tsv $method $sepmethod $type
} {tab {{1 1} {2 1} {3 1} {4 1} {5 1} {6 1}}}

test opentsv {problems.tsv} {
	set method numeric ; set sepmethod allwaysauto ; set type {}
	analyse_file data/problems.tsv $method $sepmethod $type
} {tab {{1 2} {2 2}}}

test analyse_file {data.csv} {
	set method numeric ; set sepmethod allwaysauto ; set type {}
	analyse_file data/data.csv $method $sepmethod $type
} {comma {{1 2} {2 2} {3 2} {4 1} {5 1} {6 1}}}

test opentsv {na4numbers.tsv} {
	set method numeric ; set sepmethod allwaysauto ; set type tab
	analyse_file data/na4numbers.tsv $method $sepmethod $type
} {tab {{1 2}}}

test opentsv {999 numbers} {
	set o [open tmp/test.tsv w]
	puts $o num
	for {set num 1} {$num <= 999} {incr num} {
		puts $o $num
	}
	puts $o text
	close $o
	set method numeric ; set sepmethod allwaysauto ; set type tab
	analyse_file tmp/test.tsv $method $sepmethod $type
} {tab {{1 2}}}

test opentsv {1000 numbers} {
	set o [open tmp/test.tsv w]
	puts $o num
	for {set num 1} {$num <= 1000} {incr num} {
		puts $o $num
	}
	puts $o text
	close $o
	set method numeric ; set sepmethod allwaysauto ; set type tab
	analyse_file tmp/test.tsv $method $sepmethod $type
} {tab {{1 1}}}

test opentsv {test_excel_import.txt} {
	exec ../opentsv.tcl data/test_excel_import.txt
} {workbooks -namedarg OpenText Filename */test_excel_import.txt DataType 1 Comma 0 Tab 1 Semicolon 0 Space 0 TextQualifier 1 FieldInfo {{1 2} {2 1}}} match

test opentsv {GSE6857_series_matrix.txt.gz} {
	# test suggested by reviewer, caused problems because it is not really a tsv in the original definition:
	# could not find correct header/nr of columns because ! for comments
	exec zcat data/GSE6857_series_matrix.txt.gz > tmp/GSE6857_series_matrix.txt
	set expected [list tab [list_mangle [list_fill 483 1 1] [list_fill 483 2]]]
	set result [analyse_file tmp/GSE6857_series_matrix.txt numeric allwaysauto tab]
	expr {$result == $expected}
} 1

test opentsv {comma only accepts decimal point} {
	file_write tmp/test.csv [deindent {
		a,b,c
		1,1,"1,0"
		b,2.0,2
	}]\n
	analyse_file tmp/test.csv numeric {} {}
} {comma {{1 2} {2 1} {3 2}}}

test opentsv {semicolon accepts both decimal comma and point} {
	file_write tmp/test.csv [deindent {
		a;b;c
		a;1;1.0
		b;2,0;2.0
	}]\n
	analyse_file tmp/test.csv numeric {} {}
} {semicolon {{1 2} {2 1} {3 1}}}

test opentsv {space separator} {
	file_write tmp/test.csv [deindent {
		a b c
		1 1 5e1
		b 2.0 2
	}]\n
	analyse_file tmp/test.csv numeric {} {}
} {space {{1 2} {2 1} {3 2}}}

test opentsv {issafe} {
	set o [open tmp/result.tsv w]
	foreach line [split [string trim [file_read data/test_excel_import.txt]] \n] {
		if {[string index $line 0] eq "\#" || $line eq ""} {
			puts $o $line
			continue
		}
		foreach {el expected} [split $line \t] break
		if {[issafe $el]} {
			puts $o $el\t1
		} else {
			puts $o $el\t0
		}
	}
	close $o
	exec diff tmp/result.tsv data/test_excel_import.txt
} {}

test opentsv {header issafe} {
	file_write tmp/test.tsv [deindent {
		a	march1	1-1
		1	2	3
	}]\n
	analyse_file tmp/test.tsv numeric {} {}
} {tab {{1 1} {2 2} {3 2}}}


testsummarize
