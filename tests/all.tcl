#!/bin/sh
# the next line restarts using wish \
exec tclsh "$0" "$@"

source tools.tcl

settings method numeric
settings sepmethod allwaysauto
settings numformat dpoint
numformat dpoint

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

test opentsv {comma separated, numformat dpoint (default)} {
	file_write tmp/test.csv [deindent {
		a,b,c
		1,1,"1,0"
		b,2.0,2
	}]\n
	analyse_file tmp/test.csv numeric {} {}
} {comma {{1 2} {2 1} {3 2}}}

test opentsv {semicolon separated, numformat dpoint} {
	file_write tmp/test.csv [deindent {
		a;b;c
		a;1;1.0
		b;2,0;2.0
	}]\n
	analyse_file tmp/test.csv numeric {} {} dpoint
} {semicolon {{1 2} {2 2} {3 1}}}

test opentsv {space separator} {
	file_write tmp/test.csv [deindent {
		a b c
		1 1 5e1
		b 2.0 2
	}]\n
	analyse_file tmp/test.csv numeric {} {}
} {space {{1 2} {2 1} {3 2}}}

test opentsv {numformat dpoint} {
	file_write tmp/test.csv [deindent {
		a	b	c	d	e	f	g
		1	1	1,0	1.000,1	1	1,000	1.000
		0	2.0	2	2	2,000.1	1,102,102.1	1.102.102,1
	}]\n
	analyse_file tmp/test.csv numeric {} {} dpoint
} {tab {{1 1} {2 1} {3 2} {4 2} {5 2} {6 2} {7 2}}}

test opentsv {numformat dcomma} {
	file_write tmp/test.csv [deindent {
		a	b	c	d	e	f	g
		1	1	1,0	1.000,1	1	1,000	1.000
		0	2.0	2	2	2,000.1	1,102,102.1	1.102.102,1
	}]\n
	analyse_file tmp/test.csv numeric {} {} dcomma
} {tab {{1 1} {2 2} {3 1} {4 2} {5 2} {6 2} {7 2}}}

test opentsv {numformat dpointthousand} {
	file_write tmp/test.csv [deindent {
		a	b	c	d	e	f	g
		1	1	1,0	1.000,1	1	1,000	1.000
		0	2.0	2	2	2,000.1	1,102,102.1	1.102.102,1
	}]\n
	analyse_file tmp/test.csv numeric {} {} dpointthousand
} {tab {{1 1} {2 1} {3 2} {4 2} {5 1} {6 1} {7 2}}}

test opentsv {numformat dcommathousand} {
	file_write tmp/test.csv [deindent {
		a	b	c	d	e	f	g
		1	1	1,0	1.000,1	1	1,000	1.000
		0	2.0	2	2	2,000.1	1,102,102.1	1.102.102,1
	}]\n
	analyse_file tmp/test.csv numeric {} {} dcommathousand
} {tab {{1 1} {2 2} {3 1} {4 1} {5 2} {6 2} {7 1}}}

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
		a	APR-1	1-1
		1	2	3
	}]\n
	analyse_file tmp/test.tsv numeric {} {}
} {tab {{1 1} {2 2} {3 2}}}

test opentsv {unsafe comment} {
	file_write tmp/test.tsv [deindent {
		#a	APR-1
		a	b	1-1
		1	2	3
	}]\n
	analyse_file tmp/test.tsv numeric {} {}
} {tab {{1 1} {2 2} {3 2}}}

test opentsv {header issafe} {
	exec zcat data/GSE6857_series_matrix.txt.gz > tmp/GSE6857_series_matrix.txt
	analyse_file tmp/GSE6857_series_matrix.txt numeric {} {}
} {tab {{1 2} {2 2} {3 2} {4 2} {5 2} {6 2} {7 2} {8 2} {9 2} {10 2} {11 2} {12 2} {13 2} {14 2} {15 2} {16 2} {17 2} {18 2} {19 2} {20 2} {21 2} {22 2} {23 2} {24 2} {25 2} {26 2} {27 2} {28 2} {29 2} {30 2} {31 2} {32 2} {33 2} {34 2} {35 2} {36 2} {37 2} {38 2} {39 2} {40 2} {41 2} {42 2} {43 2} {44 2} {45 2} {46 2} {47 2} {48 2} {49 2} {50 2} {51 2} {52 2} {53 2} {54 2} {55 2} {56 2} {57 2} {58 2} {59 2} {60 2} {61 2} {62 2} {63 2} {64 2} {65 2} {66 2} {67 2} {68 2} {69 2} {70 2} {71 2} {72 2} {73 2} {74 2} {75 2} {76 2} {77 2} {78 2} {79 2} {80 2} {81 2} {82 2} {83 2} {84 2} {85 2} {86 2} {87 2} {88 2} {89 2} {90 2} {91 2} {92 2} {93 2} {94 2} {95 2} {96 2} {97 2} {98 2} {99 2} {100 2} {101 2} {102 2} {103 2} {104 2} {105 2} {106 2} {107 2} {108 2} {109 2} {110 2} {111 2} {112 2} {113 2} {114 2} {115 2} {116 2} {117 2} {118 2} {119 2} {120 2} {121 2} {122 2} {123 2} {124 2} {125 2} {126 2} {127 2} {128 2} {129 2} {130 2} {131 2} {132 2} {133 2} {134 2} {135 2} {136 2} {137 2} {138 2} {139 2} {140 2} {141 2} {142 2} {143 2} {144 2} {145 2} {146 2} {147 2} {148 2} {149 2} {150 2} {151 2} {152 2} {153 2} {154 2} {155 2} {156 2} {157 2} {158 2} {159 2} {160 2} {161 2} {162 2} {163 2} {164 2} {165 2} {166 2} {167 2} {168 2} {169 2} {170 2} {171 2} {172 2} {173 2} {174 2} {175 2} {176 2} {177 2} {178 2} {179 2} {180 2} {181 2} {182 2} {183 2} {184 2} {185 2} {186 2} {187 2} {188 2} {189 2} {190 2} {191 2} {192 2} {193 2} {194 2} {195 2} {196 2} {197 2} {198 2} {199 2} {200 2} {201 2} {202 2} {203 2} {204 2} {205 2} {206 2} {207 2} {208 2} {209 2} {210 2} {211 2} {212 2} {213 2} {214 2} {215 2} {216 2} {217 2} {218 2} {219 2} {220 2} {221 2} {222 2} {223 2} {224 2} {225 2} {226 2} {227 2} {228 2} {229 2} {230 2} {231 2} {232 2} {233 2} {234 2} {235 2} {236 2} {237 2} {238 2} {239 2} {240 2} {241 2} {242 2} {243 2} {244 2} {245 2} {246 2} {247 2} {248 2} {249 2} {250 2} {251 2} {252 2} {253 2} {254 2} {255 2} {256 2} {257 2} {258 2} {259 2} {260 2} {261 2} {262 2} {263 2} {264 2} {265 2} {266 2} {267 2} {268 2} {269 2} {270 2} {271 2} {272 2} {273 2} {274 2} {275 2} {276 2} {277 2} {278 2} {279 2} {280 2} {281 2} {282 2} {283 2} {284 2} {285 2} {286 2} {287 2} {288 2} {289 2} {290 2} {291 2} {292 2} {293 2} {294 2} {295 2} {296 2} {297 2} {298 2} {299 2} {300 2} {301 2} {302 2} {303 2} {304 2} {305 2} {306 2} {307 2} {308 2} {309 2} {310 2} {311 2} {312 2} {313 2} {314 2} {315 2} {316 2} {317 2} {318 2} {319 2} {320 2} {321 2} {322 2} {323 2} {324 2} {325 2} {326 2} {327 2} {328 2} {329 2} {330 2} {331 2} {332 2} {333 2} {334 2} {335 2} {336 2} {337 2} {338 2} {339 2} {340 2} {341 2} {342 2} {343 2} {344 2} {345 2} {346 2} {347 2} {348 2} {349 2} {350 2} {351 2} {352 2} {353 2} {354 2} {355 2} {356 2} {357 2} {358 2} {359 2} {360 2} {361 2} {362 2} {363 2} {364 2} {365 2} {366 2} {367 2} {368 2} {369 2} {370 2} {371 2} {372 2} {373 2} {374 2} {375 2} {376 2} {377 2} {378 2} {379 2} {380 2} {381 2} {382 2} {383 2} {384 2} {385 2} {386 2} {387 2} {388 2} {389 2} {390 2} {391 2} {392 2} {393 2} {394 2} {395 2} {396 2} {397 2} {398 2} {399 2} {400 2} {401 2} {402 2} {403 2} {404 2} {405 2} {406 2} {407 2} {408 2} {409 2} {410 2} {411 2} {412 2} {413 2} {414 2} {415 2} {416 2} {417 2} {418 2} {419 2} {420 2} {421 2} {422 2} {423 2} {424 2} {425 2} {426 2} {427 2} {428 2} {429 2} {430 2} {431 2} {432 2} {433 2} {434 2} {435 2} {436 2} {437 2} {438 2} {439 2} {440 2} {441 2} {442 2} {443 2} {444 2} {445 2} {446 2} {447 2} {448 2} {449 2} {450 2} {451 2} {452 2} {453 2} {454 2} {455 2} {456 2} {457 2} {458 2} {459 2} {460 2} {461 2} {462 2} {463 2} {464 2} {465 2} {466 2} {467 2} {468 2} {469 2} {470 2} {471 2} {472 2} {473 2} {474 2} {475 2} {476 2} {477 2} {478 2} {479 2} {480 2} {481 2} {482 2} {483 2}}}

testsummarize
