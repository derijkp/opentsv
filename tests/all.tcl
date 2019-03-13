#!/bin/sh
# the next line restarts using wish \
exec tclsh "$0" "$@"

source tools.tcl

settings method numeric
settings sepmethod allwaysauto

test opentsv {data.tsv} {
	exec ../opentsv.tcl data/data.tsv
} {workbooks -namedarg OpenText Filename */data.tsv DataType 1 Comma 0 Tab 1 Semicolon 0 Space 0 TextQualifier 1 FieldInfo {{1 2} {2 2} {3 2} {4 1} {5 1} {6 1}}} match

test opentsv {problems.tsv} {
	exec ../opentsv.tcl data/problems.tsv
} {workbooks -namedarg OpenText Filename */problems.tsv DataType 1 Comma 0 Tab 1 Semicolon 0 Space 0 TextQualifier 1 FieldInfo {{1 2} {2 2}}} match

test analyse_file {data.tsv} {
	set method numeric ; set sepmethod allwaysauto ; set type {}
	analyse_file data/data.tsv $method $sepmethod $type
} {tab {{1 2} {2 2} {3 2} {4 1} {5 1} {6 1}}} match

test analyse_file {data.tsv} {
	set method all ; set sepmethod allwaysauto ; set type {}
	analyse_file data/data.tsv $method $sepmethod $type
} {tab {{1 2} {2 2} {3 2} {4 2} {5 2} {6 2}}} match

test analyse_file {data.tsv} {
	set method convall ; set sepmethod allwaysauto ; set type {}
	analyse_file data/data.tsv $method $sepmethod $type
} {tab {{1 1} {2 1} {3 1} {4 1} {5 1} {6 1}}} match

test opentsv {problems.tsv} {
	set method numeric ; set sepmethod allwaysauto ; set type {}
	analyse_file data/problems.tsv $method $sepmethod $type
} {tab {{1 2} {2 2}}} match

test analyse_file {data.csv} {
	set method numeric ; set sepmethod allwaysauto ; set type {}
	analyse_file data/data.csv $method $sepmethod $type
} {comma {{1 2} {2 2} {3 2} {4 1} {5 1} {6 1}}} match

test opentsv {na4numbers.tsv} {
	set method numeric ; set sepmethod allwaysauto ; set type tab
	analyse_file data/na4numbers.tsv $method $sepmethod $type
} {tab {{1 2}}} match

test opentsv {9 numbers} {
	set o [open tmp/test.tsv w]
	puts $o num
	for {set num 1} {$num <= 999} {incr num} {
		puts $o $num
	}
	puts $o text
	close $o
	set method numeric ; set sepmethod allwaysauto ; set type tab
	analyse_file tmp/test.tsv $method $sepmethod $type
} {tab {{1 2}}} match

test opentsv {10 numbers} {
	set o [open tmp/test.tsv w]
	puts $o num
	for {set num 1} {$num <= 1000} {incr num} {
		puts $o $num
	}
	puts $o text
	close $o
	set method numeric ; set sepmethod allwaysauto ; set type tab
	analyse_file tmp/test.tsv $method $sepmethod $type
} {tab {{1 1}}} match

testsummarize
