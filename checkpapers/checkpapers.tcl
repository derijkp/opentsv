#!/bin/sh
# the next line restarts using wish \
exec cg source "$0" ${1+"$@"}

# intro
# =====
# Screens several journals for papers with xls(x) supplemtary files, and
# checks for common Excel conversion errors
#
# It should be run using the geneomcomb shell (cg source, or use cg sh to run manually)
#
# written by Peter De Rijk (VIB)
# inspired by ideas from Mark Ziemann mark.ziemann@gmail.com
#
# results as tab-delimted tables (<source>_result.txt) containing at least one line per paper 
# with the following fields:
#
# source: journal/db
# year: year of publication
# id: id identifying paper/db entry
# url: url of paper/db entry
# suppfile: supplementary file url, empty if no supplementary xls(x) file was found, if more than one -> multiple lines
# genelist: 1 if it contains genelist; 0 if xls(x), but no genelist, n for no xls(x) suppl, s for (xls/zip) parse error
# geneerrors: number of errors, 0 for xls without errors, n for no xls(x) suppl, s for (xls/zip) parse error


# prepare
# =======

cd ~/data/peter/Articles/2018_opentsv/checkpapers

package require tdom

set genelists [glob ~/data/peter/Articles/2018_opentsv/code_others/GeneNameErrorsScreen/genelists/*genes]
foreach file $genelists {
	set species [string range [file tail $file] 0 end-6]
	set genelista($species) [split [string trim [file_read $file]] \n]
	foreach gene $genelista($species) {
		lappend genea($gene) $species
	}
}

set ::env(webcache) $env(HOME)/tmp/webcache

# procedures
# ==========

proc backup file {
	if {![file exists $file]} return
	set num 0
	while {[file exists $file.old$num]} {incr num}
	file rename $file $file.old$num
}

proc baseurl url {
	if {[regexp {^[^?]*\.zip} $url temp]} {
		return $temp
	} elseif {[regexp {^[^?]*\.gz} $url temp]} {
		return $temp
	} elseif {[regexp {^[^?]*\.xlsx?} $url temp]} {
		return $temp
	} else {
		return $url
	}
}

proc wgetfile {url {resultfile {}} {force 0} {maxsize {}} {removecache 0}} {
	if {$resultfile eq ""} {
		set resultfile [file tail $url]
	}
	if {!$force && [file exists $resultfile]} {return $resultfile}
	file delete -force $resultfile.temp
	set tail [file tail $url]
	if {[info exists ::env(webcache)]} {
		set webcache $::env(webcache)
	} else {
		set webcache [tempdir]/webcache
	}
	file mkdir $webcache
	regsub -all {[:/]} [baseurl $url] _ temp
	set webcachename $webcache/$temp
	if {$webcache ne "" && $removecache} {file delete $webcachename}
	if {$webcache ne "" && [file exists $webcachename]} {
		putslog "Getting from webcache: $tail"
		if {[catch {hardlink $webcachename $resultfile.temp}]} {
			file copy $webcachename $resultfile.temp
		}
	} else {
		set wait [get ::wgetwait 500]
		after [expr {round($wait+2000*rand())}]
		if {[catch {
			if {$maxsize ne ""} {
				set temp {}
				catch {exec wget --spider --span-hosts --user-agent "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.22 (KHTML, like Gecko) Ubuntu Chromium/25.0.1364.160 Chrome/25.0.1364.160 Safari/537.22" $url} temp
				if {[regexp {Length: ([0-9]+)} $temp t size]} {
					if {$size > $maxsize} {error "File > $maxsize: $url"}
				}
			}
			exec wget --tries=2 --timeout=3 --waitretry=4 --span-hosts \
				--no-check-certificate \
				--user-agent "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.22 (KHTML, like Gecko) Ubuntu Chromium/25.0.1364.160 Chrome/25.0.1364.160 Safari/537.22" \
				-O $resultfile.temp $url 2>@ stderr
		} errmsg]} {
			puts stderr $errmsg
			if {![file exists $resultfile.temp]} {
				return {}
			}
			if {[file size $resultfile.temp] == 0} {
				file delete $resultfile.temp
			}
			return {}
		}
		if {![file exists $resultfile.temp]} {
			return {}
		}
		if {[regexp "No such file" $errmsg]} {
			file delete $resultfile.temp
			return {}
		}
		if {$webcache ne ""} {
			if {[catch {hardlink $resultfile.temp $webcachename.temp}]} {
				file copy $resultfile.temp $webcachename.temp
			}
			file rename -force $webcachename.temp $webcachename
		}
	}
	file rename -force $resultfile.temp $resultfile
	return $resultfile
}

proc checkonexls {xlsfile} {
	global genea
	# ssconvert sometimes hangs, so run in bg, and kill after 10 seconds if not finished
	set f [open "| ssconvert -S --export-type Gnumeric_stf:stf_assistant -O \{separator=\'\t\'\} \
			$xlsfile $xlsfile.txt" ]
	set pid [pid $f]
	set num 1
	fconfigure $f -blocking 0 
	while {![eof $f]} {
		after 100
		if {[incr num 1] > 100} {
			puts "Killing (ssconvert $xlsfile) after 10 seconds"
			catch {close $f}
			catch {exec kill $pid}
			return s\ts
		}
		gets $f
	}
	catch {close $f} msg
	set genelist 0
	set geneerror 0
	foreach file [glob -nocomplain $xlsfile.txt*] {
		unset -nocomplain a
		unset -nocomplain b
		set genelistcols {}
		# preview 20
		set c [exec head -20 $file]
		foreach line [split $c \n] {
			set num 0
			foreach el [split $line \t] {
				if {[info exists genea($el)] && [string length $el] > 2 && ![info exists b($num,$el)]} {
					if {![info exists a($num)]} {
						set a($num) 1
						set b($num,$el) 1
					} else {
						incr a($num)
					}
				}
				incr num
			}
		}
		foreach col [array names a] {
			if {$a($col) >= 4} {
				lappend genelistcols $col
			}
		}
		if {[llength $genelistcols]} {
			set genelist 1
			set c [split [string trim [file_read $file]] \n]
			foreach line $c {
				set line [split $line \t]
				set genes [list_sub $line $genelistcols]
				foreach gene $genes {
					if {[regexp {[0-9][0-9][/-][0-9][0-9][-/][0-9][0-9]} $gene]
						|| [regexp {^[0-9]\-(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)$} $gene]
						|| [regexp {[0-9]\.[0-9][0-9]E\+[0-9][0-9]} $gene]
					} {
						incr geneerror
						# return 1\t1
					}
				}
			}
		}
	}
	return $genelist\t$geneerror
}

proc scanfile fileurl {
	if {$fileurl eq ""} {
		return n\tn
	}
	set tempdir [tempdir]
	set tempfile [tempfile]
	exec chmod -R u+w $tempdir
	foreach tfile [glob -nocomplain $tempdir/*] {file delete -force $tfile}
	set xlsfile $tempdir/[file tail [baseurl $fileurl]]
	wgetfile $fileurl $xlsfile 1 1000000000
	if {![file exists $xlsfile]} {
		return n\tn
	}
	set ext [file extension $xlsfile]
	if {$ext eq ".zip"} {
		file mkdir $tempdir/temp
		if {[catch {exec unzip -d $tempdir/temp $xlsfile}] || [catch {glob $tempdir/temp/*.xls*} files]} {
			return n\tn
		}
		set genelist 0
		set geneerrors 0
		foreach file $files {
			foreach {l e} [checkonexls $file] break
			if {$l eq "1"} {set genelist 1}
			if {[isint $e]} {
				incr geneerrors $e
			}
		}
		return $genelist\t$geneerrors
	} elseif {$ext eq ".gz"} {
		if {[catch {exec gunzip -f $xlsfile} msg]} {
			puts "error unzipping $fileurl: $msg"
			return n\tn
		}
		set xlsfile [file root $xlsfile]
	}
	set temp [checkonexls $xlsfile]
}

proc scanfiles {files result} {
	set source [lindex [split $result _] 0]
	set tempdir [tempdir]
	set cfiles [split [string trim [file_read $files] \n] \n]
	set header [list_pop cfiles 0]
	if {$header ne "source\tyear\tid\turl\tsuppfile"} {error "File $files has incorrect header"}
	#
	backup $result
	catch {close $o} ; set o [open $result w]
	puts $o $header\tgenelist\tgeneerrors
	set len [llength $cfiles]
	set num 0
	foreach line $cfiles {
		set sline [split $line \t]
		set fileurl [lindex $sline end]
		puts "[incr num]/$len. scanning $source $fileurl"
		if {$fileurl eq ""} {
			puts $o $line\tn\tn
			flush $o
			continue
		}
		set temp [scanfile $fileurl]
		append line \t$temp
		puts $o $line
		flush $o
	}
	close $o
}

proc getsuppfiles_parse {c {patterns {}}} {
	if {$patterns eq ""} {
		set patterns {
			{href="([^">\n]+\.xlsx?[^">\n]*)"}
			{href="([^">\n]+\.zip[^">\n]*)"}
			{href="([^">\n]+\.xlsx?\.gz[^">\n]*)"}
			{href=([^">\n]+\.xlsx?[^ ">\n]*)}
			{href=([^">\n]+\.zip[^ ">\n]*)}
			{href=([^">\n]+\.xlsx?\.gz[^ ">\n]*)}
		}
	}
	unset -nocomplain a
	set suppfiles {}
	foreach pattern $patterns {
		list_unmerge [regexp -all -inline $pattern $c] 1 temp
		foreach file $temp {
			set base [baseurl $file]
			if {![info exists a($base)]} {
				lappend suppfiles $file
				set a($base) $file
			}
		}
	}
	return $suppfiles
}

proc getsuppfiles {url tempfile {patterns {}}} {
	wgetfile $url $tempfile 1 1000000000
	if {![file exists $tempfile]} {
		puts stderr "could not download $url, skipping"
		return ""
	}
	set c [file_read $tempfile]
	getsuppfiles_parse $c $patterns
}

proc mine_geo {file result {patterns {}}} {
	set source geo
	regexp {[0-9]+} $file year
	set tempfile [tempfile]
	set list [split [string trim [exec cg zcat $file | grep {FTP download:}]] \n]
	backup $result
	catch {close $o} ; set o [open $result w]
	puts $o "source\tyear\tid\turl\tsuppfile"
	set len [llength $list]
	set num 0
	foreach line $list {
		if {[regexp {ftp:[^ \n]+} $line url]} {
		} elseif {[regexp {https?:[^ \n]+} $line url]} {
		} else {
			error "no url"
		}
		puts "[incr num]/$len. mining geo $url"
		set id [lindex [file split $url] end]
		file delete $tempfile
		set suppfiles {}
		wgetfile $url/suppl/ $tempfile 1 1000000000
		if {![file exists $tempfile]} {
			# wait 30 seconds and rty again
			after 30000
			wgetfile $url/suppl/ $tempfile 1 1000000000
		}
		if {[file exists $tempfile]} {
			set c [file_read $tempfile]
			lappend suppfiles {*}[getsuppfiles_parse $c $patterns]
		}
		if {![file exists $tempfile]} {
			wgetfile $url $tempfile 1 1000000000
		}
		if {[file exists $tempfile]} {
			set c [file_read $tempfile]
			lappend suppfiles {*}[getsuppfiles_parse $c $patterns]
		}
		set suppfiles [list_remdup $suppfiles]
		if {![llength $suppfiles]} {
			puts $o "$source\t$year\t$id\t$url\t"
			flush $o
		} else {
			foreach file $suppfiles {
				regsub {href="?} $file {} file
				if {[string index $file 0] eq "/"} {set file https://doi.org/$doi/$file}
				puts $o "$source\t$year\t$id\t$url\t$file"
				flush $o
			}
		}
	}
	close $o
}

proc gzread file {
	set f [gzopen $file]
	set c [read $f]
	gzclose $f
	return $c
}

proc mine_pubmed {file result {patterns {}}} {
	backup $result
	set tempdir [tempdir]
	set tempfile [tempfile]
	set source [lindex [split [file tail $file] _] 0]
	set doc [dom parse [gzread $file]]
	set root [$doc documentElement]
	set articles [$root selectNodes /PubmedArticleSet/PubmedArticle]
	backup $result
	catch {close $o} ; set o [open $result.temp w]
	puts $o "source\tyear\tid\turl\tsuppfile"
	set len [llength $articles]
	set num 0
	foreach article $articles {
		set pubmed [[$article selectNodes {PubmedData/ArticleIdList/ArticleId[@IdType='pubmed']/text()}] data]
		set n [$article selectNodes {PubmedData/ArticleIdList/ArticleId[@IdType='doi']/text()}]
		if {$n eq ""} {
			puts "skipping $pubmed, no doi found"
			continue
		}
		set doi [$n data]
		set d [$article selectNodes MedlineCitation/Article/Journal/JournalIssue/PubDate/Year/text()]
		if {$d eq ""} {
			set d [$article selectNodes MedlineCitation/Article/Journal/JournalIssue/PubDate/MedlineDate/text()]
		}
		set year [$d data]
		puts "[incr num]/$len. mining $source $pubmed"
		set id $pubmed
		set url https://doi.org/$doi
		regsub -all / $doi _ fdoi
		set suppfiles [getsuppfiles $url $tempfile $patterns]
		# putsvars pubmed doi year id url suppfiles
		if {![llength $suppfiles]} {
			puts $o "$source\t$year\t$id\t$url\t"
			flush $o
		} else {
			foreach file $suppfiles {
				regsub {href="?} $file {} file
				if {[string index $file 0] eq "/"} {set file https://doi.org/$doi/$file}
				puts $o "$source\t$year\t$id\t$url\t$file"
				flush $o
			}
		}
	}
	close $o
	file rename $result.temp $result
}

# from website
# ------------

proc mine_bmc {source result mainurl} {
	set tempdir [tempdir]
	set tempfile [tempfile]
	wgetfile $mainurl/articles?query=&volume=&searchType=&tab=keyword $tempdir/q.html 1 1000000000
	set c [file_read $tempdir/q.html]
	if {[regexp {Page 1 of ([0-9]+)} $c temp nf]} {
	} else {
		error "nr of pages not found for $mainurl"
	}
	backup $result
	catch {close $o} ; set o [open $result.temp w]
	puts $o "source\tyear\tid\turl\tsuppfile"
	for {set page 1} {$page <= $nf} {incr page} {
		wgetfile "$mainurl/articles?tab=keyword&searchType=journalSearch&sort=PubDate&page=${page}" $tempdir/$page.html 1 1000000000
		set c [file_read $tempdir/$page.html]
		list_unmerge [regexp -all -inline {"(/articles/[^"]+)"} $c] 1 articles
		set len [llength $articles]
		set num 0
		foreach article $articles {
			set id $article
			set url $mainurl$article
			puts "Page $page/$nf Art [incr num]/$len mining $source $article $url"
			file delete $tempfile
			wgetfile $url $tempfile 1 1000000000
			set c [file_read $tempfile]
			if {![regexp {<meta name=["]dc\.source["][^>]*(20[0-9][0-9])} $c temp year]} {
				puts "Could not get year for $article"
				continue
			}
			set suppfiles [regexp -all -inline {href="[^">\n]+\.xlsx?} $c]
			lappend suppfiles {*}[regexp -all -inline {href="[^">\n]+\.zip?} $c]
			if {![llength $suppfiles]} {
				puts $o "$source\t$year\t$id\t$url\t"
				flush $o
			} else {
				foreach file $suppfiles {
					regsub {href="?} $file {} file
					if {[string index $file 0] eq "/"} {set file $mainurl$file}
					puts $o "$source\t$year\t$id\t$url\t$file"
					flush $o
				}
			}
		}
	}
	close $o
	file rename $result.temp $result
}

proc mine_toc {source result mainurl tocs artpattern supppattern {patterns {}}} {
	set tempdir [tempdir]
	set tempfile [tempfile]
	backup $result
	catch {close $o} ; set o [open $result.temp w]
	puts $o "source\tyear\tid\turl\tsuppfile\tgenelist\tgeneerrors"
	foreach {year toc_urls} $tocs {
		set nf [llength $toc_urls]
		set tocnum 0
		foreach toc_url $toc_urls {
			puts "toc$year toc $tocnum/$nf $toc_url"
			incr tocnum
			wgetfile $toc_url $tempdir/toc.html 1 1000000000
			if {![file exists $tempdir/toc.html]} {
				puts stderr "could not download, skipping $toc_url"
				incr tocnum
				continue
			}
			set c [file_read $tempdir/toc.html]
			list_unmerge [regexp -all -inline $artpattern $c] 1 articles
			if {$supppattern ne ""} {
				list_unmerge [regexp -all -inline $supppattern $c] 1 supplements
			} else {
				set supplements {}
			}
			set len [llength $articles]
			set num 0
			foreach article $articles {
				set id $article
				if {[string index $article 0] eq "/"} {
					set url $mainurl$article
				} else {
					set url $article
				}
				puts "toc$year $tocnum/$nf Art [incr num]/$len mining $source $article $url"
				regsub {\.full} $article {} temp
				if {$supppattern ne ""} {
					set poss [list_find -glob $supplements $temp/*]
					set suppurls [list_sub $supplements $poss]
					set suppurls [list_remdup $suppurls]
					set suppfiles {}
					foreach suppurl $suppurls {
						lappend suppfiles {*}[getsuppfiles $mainurl$suppurl $tempfile $patterns]
					}
				} else {
					set suppfiles [getsuppfiles $url $tempfile $patterns]
				}
				if {![llength $suppfiles]} {
					puts $o "$source\t$year\t$id\t$url\t\tn\tn"
					flush $o
				} else {
					foreach file $suppfiles {
						set file [string_change $file {{&amp;} &}]
						if {[string index $file 0] eq "/"} {set file $mainurl$file}
						set temp [scanfile $file]
						puts $o "$source\t$year\t$id\t$url\t[baseurl $file]\t$temp"
						flush $o
					}
				}
			}
		}
	}
	close $o
	file rename $result.temp $result
}

proc gettocbyyear {mainurl yearurl tocpattern} {
	set tempfile [tempfile]
	set result {}
	foreach year [list_fill 10 2010 1] {
		wgetfile $yearurl/$year $tempfile 1 1000000000
		set c [file_read $tempfile]
		list_unmerge [regexp -all -inline $tocpattern $c] 1 tocs
		set tocurls {}
		foreach toc $tocs {
			lappend tocurls $mainurl$toc
		}
		lappend result $year $tocurls
	}
	return $result
}

proc def {fields field {def 0}} {
	if {$field in $fields} {return \$\{$field\}} else {return $def}
}

proc result_per_paper {result args} {
	exec cg cat {*}$args \
		| cg select -f {
			{nr_suppfiles=if($suppfile ne "",1,0)}
			{nr_genelists=def($genelist,0)}
			{nr_errors=if(def($geneerrors,0)>0,1,0)}
		} -g {year * source * id *} -gc {sum(nr_suppfiles),sum(nr_genelists),sum(nr_errors)} \
		| cg select -f {
			year id source
			{nr_suppfiles=$sum_nr_suppfiles}
			{nr_genelists=$sum_nr_genelists}
			{nr_errors=$sum_nr_errors}
			{has_suppfile=if(def($sum_nr_suppfiles,0)>0,1,0)}
			{has_genelist=if(def($sum_nr_genelists,0)>0,1,0)}
			{has_error=if(def($sum_nr_errors,0)>0,1,0)}
		} \
	> $result
}

proc make_summary {result tempfile {group year}} {
	set tempfile2 [tempfile]
	cg select -overwrite 1 -g $group -gc {has_suppfile * has_genelist * has_error * count} $tempfile $tempfile2
	set ffields [cg select -h $tempfile2]
	set fields [subst -novariables {
		{-nofile=[def $ffields count-0-0-0 0]}
		{-nogenelist=[def $ffields count-1-0-0 0]}
		{-noerror=[def $ffields count-1-1-0 0]}
		{-xerror=[def $ffields count-1-1-1 0]}
		[get group]
		{papers=$nofile + $nogenelist + $noerror + $xerror}
		{files=$nogenelist + $noerror + $xerror}
		{genelist=$noerror + $xerror}
		{error=$xerror}
		{pcterror=if(($noerror + $xerror) > 0,format("%.2f",100.0*$xerror/($noerror + $xerror)),0)}
	}]
	set temp [cg select -f $fields $tempfile2]
	puts $result\n$temp
	if {[regsub _result $result _summary summary]} {
		file_write $summary $temp\n
	}
}

proc summary {result {group year}} {
	set tempfile [tempfile]
	set tempfile2 [tempfile]
	result_per_paper $tempfile $result
	make_summary $result $tempfile $group
}




# mine geo
# ========
# geo_sources using https://www.ncbi.nlm.nih.gov/gds/?term=(((%22xls%22[Supplementary+Files]+OR+%22xlsx%22[Supplementary+Files])))+AND+(%222015%22[Publication+Date]+%3A+%222018%22[Publication+Date])
# query = ((("xls"[Supplementary Files] OR "xlsx"[Supplementary Files]))) AND ("2015"[Publication Date] : "2015"[Publication Date])
# fill in each year
foreach year {2010 2011 2012 2013 2014 2015 2016 2017 2018 2019} {
	puts "year=$year"
	if {![file exists geo_files$year.txt]} {
		mine_geo source/geo_source$year.txt geo_files$year.txt.temp
		file rename -force geo_files$year.txt.temp geo_files$year.txt
	}
}
set files [lsort -dict [glob geo_files2*.txt]]
exec cg cat -c 0 {*}$files > geo_files.txt
scanfiles geo_files.txt geo_result.txt
# summary geo
summary geo_result.txt

# cat geo_result.txt | cg select -f '{geneerr=if(def($geneerrors,0)>0,1,0)}' -g year -gc 'genelist * geneerr * ucount(id)'

# mine journals
# =============

# bmc Genome Biology
# ------------------
mine_bmc genomebiology genomebiology_files_all.txt http://genomebiology.biomedcentral.com
cg select -q {$year >= 2010} genomebiology_files_all.txt genomebiology_files.txt
scanfiles genomebiology_files.txt genomebiology_result.txt
summary genomebiology_result.txt
# cat genomebiology_result.txt | cg select -f '{geneerr=if(def($geneerrors,0)>0,1,0)}' -g year -gc 'genelist * geneerr * ucount(id)'
# check ext 
# cat genomebiology_result.txt | cg select -f '{ext=[file extension $suppfile]} {geneerr=if(def($geneerrors,0)>0,1,0)}' -g 'year * ext * genelist *' -gc 'ucount(id)'

# bmc Genomics
# ------------
mine_bmc bmcgenomics bmcgenomics_files_all.txt https://bmcgenomics.biomedcentral.com
cg select -q {$year >= 2010} bmcgenomics_files_all.txt bmcgenomics_files.txt
set files bmcgenomics_files.txt ; set result bmcgenomics_result.txt
scanfiles bmcgenomics_files.txt bmcgenomics_result.txt
summary bmcgenomics_result.txt
# cat bmcgenomics_result.txt | cg select -f '{geneerr=if(def($geneerrors,0)>0,1,0)}' -g year -gc 'genelist * geneerr * ucount(id)'

# bmc Bioinformatics
# ------------------
mine_bmc bmcbioinformatics bmcbioinformatics_files_all.txt https://bmcbioinformatics.biomedcentral.com
cg select -q {$year >= 2010} bmcbioinformatics_files_all.txt bmcbioinformatics_files.txt
scanfiles bmcbioinformatics_files.txt bmcbioinformatics_result.txt
summary bmcbioinformatics_result.txt
# cat bmcbioinformatics_result.txt | cg select -f '{geneerr=if(def($geneerrors,0)>0,1,0)}' -g year -gc 'genelist * geneerr * ucount(id)'

# genome research
# ---------------
set source genomeresearch
set result genomeresearch_result.txt
set mainurl http://genome.cshlp.org
set vols [list_fill 10 20 1]
set issues [list_fill 12 1 1]
set tocs {}
foreach vol $vols year [list_fill 10 2010 1] {
	set toc_urls {}
	foreach iss $issues {
		lappend toc_urls $mainurl/content/$vol/$iss.toc
	}
	lappend tocs $year $toc_urls
}
set artpattern {"(/content/[^"]+full)"}
set supppattern {"(/content/[^"]+/suppl/[^"]+)"}
set patterns {}
set wgetwait 3000
mine_toc $source $result $mainurl $tocs $artpattern $supppattern
unset wgetwait
summary genomeresearch_result.txt
# cat genomeresearch_result.txt | cg select -f '{geneerr=if(def($geneerrors,0)>0,1,0)}' -g year -gc 'genelist * geneerr * ucount(id)'

# genes and development
# ---------------------
set source genesdev
set result genesdev_result.txt
set mainurl http://genesdev.cshlp.org
set vols [list_fill 9 24 1]
set issues [list_fill 24 1 1]
set yearurl $mainurl/content/by/year
set tocpattern {"(/content/vol[^"]+)"}
set tocs [gettocbyyear $mainurl $yearurl $tocpattern]
set artpattern {"(/content/[^"]+full)"}
set supppattern {"(/content/[^"]+/suppl/[^"]+)"}
set wgetwait 3000
mine_toc $source $result $mainurl $tocs $artpattern $supppattern
unset wgetwait
summary genesdev_result.txt
# cat genesdev_result.txt | cg select -f '{geneerr=if(def($geneerrors,0)>0,1,0)}' -g year -gc 'genelist * geneerr * ucount(id)'

# nucleic acids research
# ----------------------
set source nar
set result nar_result.txt
set mainurl https://academic.oup.com/nar
set vols [list_fill 10 38 1]
set issues [list_fill 22 1 1]
set tocs {}
foreach vol $vols year [list_fill 10 2010 1] {
	set toc_urls {}
	foreach iss $issues {
		lappend toc_urls $mainurl/issue/$vol/$iss
	}
	lappend tocs $year $toc_urls
}
set artpattern {"(/nar/article/[^"]+[0-9])"}
set supppattern {}
mine_toc $source $result $mainurl $tocs $artpattern $supppattern
summary nar_result.txt
# cat nar_result.txt | cg select -f '{geneerr=if(def($geneerrors,0)>0,1,0)}' -g year -gc 'genelist * geneerr * ucount(id)'

# nature genetics
# ---------------
# todo: xls not in toc, but in articles href="https://static-content.springer.com/esm/art%3A10.1038%2Fs41588-018-0251-4/MediaObjects/41588_2018_251_MOESM4_ESM.xlsx
set source naturegenetics
set result naturegenetics_result.txt
set mainurl http://www.nature.com
set vols [list_fill 10 42 1]
set issues [list_fill 12 1 1]
set tocs {}
foreach vol $vols year [list_fill 10 2010 1] {
	set toc_urls {}
	foreach iss $issues {
		lappend toc_urls $mainurl/ng/volumes/$vol/issues/$iss
	}
	lappend tocs $year $toc_urls
}
set artpattern {"(/articles/[^"]+[0-9])"}
set supppattern {}
mine_toc $source $result $mainurl $tocs $artpattern $supppattern
summary naturegenetics_result.txt
# cat naturegenetics_result.txt | cg select -f '{geneerr=if(def($geneerrors,0)>0,1,0)}' -g year -gc 'genelist * geneerr * ucount(id)'

# human molecular genetics
# ------------------------
set source hmg
set result hmg_result.txt
set mainurl https://academic.oup.com/hmg
set vols [list_fill 10 19 1]
set issues [list_fill 25 1 1]
set tocs {}
foreach vol $vols year [list_fill 10 2010 1] {
	set toc_urls {}
	foreach iss $issues {
		lappend toc_urls $mainurl/issue/$vol/$iss
	}
	lappend tocs $year $toc_urls
}
set artpattern {"(/hmg/article/[^"]+[0-9])"}
set supppattern {}
# catch {file delete {*}[glob $::env(webcache)/*_hmg_article_*]}
mine_toc $source $result $mainurl $tocs $artpattern $supppattern
summary hmg_result.txt
# cat hmg_result.txt | cg select -f '{geneerr=if(def($geneerrors,0)>0,1,0)}' -g year -gc 'genelist * geneerr * ucount(id)'

# bioinformatics
# --------------
set source bioinformatics
set result bioinformatics_result.txt
set mainurl https://academic.oup.com/bioinformatics
set vols [list_fill 10 26 1]
set issues [list_fill 24 1 1]
set tocs {}
foreach vol $vols year [list_fill 10 2010 1] {
	set toc_urls {}
	foreach iss $issues {
		lappend toc_urls $mainurl/issue/$vol/$iss
	}
	lappend tocs $year $toc_urls
}
set artpattern {"(/bioinformatics/article/[^"]+[0-9])"}
set supppattern {}
mine_toc $source $result $mainurl $tocs $artpattern $supppattern
summary bioinformatics_result.txt
# cat bioinformatics_result.txt | cg select -f '{geneerr=if(def($geneerrors,0)>0,1,0)}' -g year -gc 'genelist * geneerr * ucount(id)'

# Mol Biol Evol
# -------------
set source mbe
set result mbe_result.txt
set mainurl https://academic.oup.com/mbe
set vols [list_fill 10 27 1]
set issues [list_fill 12 1 1]
set tocs {}
foreach vol $vols year [list_fill 10 2010 1] {
	set toc_urls {}
	foreach iss $issues {
		lappend toc_urls $mainurl/issue/$vol/$iss
	}
	lappend tocs $year $toc_urls
}
set artpattern {"(/mbe/article/[^"]+[0-9])"}
set supppattern {}
mine_toc $source $result $mainurl $tocs $artpattern $supppattern
summary mbe_result.txt
# cat mbe_result.txt | cg select -f '{geneerr=if(def($geneerrors,0)>0,1,0)}' -g year -gc 'genelist * geneerr * ucount(id)'

# rna
# ---
set source rna
set result rna_result.txt
set mainurl http://rnajournal.cshlp.org
set yearurl $mainurl/content/by/year
set tocpattern {"(/content/vol[^"]+)"}
set tocs [gettocbyyear $mainurl $yearurl $tocpattern]
set artpattern {"(/content/[^"]+full)"}
set supppattern {"(/content/[^"]+/suppl/[^"]+)"}
mine_toc $source $result $mainurl $tocs $artpattern $supppattern
summary rna_result.txt
# cat rna_result.txt | cg select -f '{geneerr=if(def($geneerrors,0)>0,1,0)}' -g year -gc 'genelist * geneerr * ucount(id)'

# nature
# ------
# Input file: go to NCBI pubmed, perform an advanced search based on
# Journal name and date of publication
# search:
# https://www.ncbi.nlm.nih.gov/pubmed/?term=(%22Nature%22[Journal])+AND+(%222010%22[Date+-+Publication]+%3A+%222019%22[Date+-+Publication])
# query: ("Nature"[Journal]) AND ("2010"[Date - Publication] : "2019"[Date - Publication]) 
# save the xml as the source:
set source nature
set file source/nature_source.xml.zst
set result nature_files.txt
mine_pubmed $file $result
set files nature_files.txt ; set result nature_result.txt
scanfiles nature_files.txt nature_result.txt
summary nature_result.txt
# cat nature_result.txt | cg select -f '{geneerr=if(def($geneerrors,0)>0,1,0)}' -g year -gc 'genelist * geneerr * ucount(id)'

# plos one
# --------
# Input file: go to NCBI pubmed, perform an advanced search based on
# Journal name and date of publication
# plosone_source.xml made using:
# https://www.ncbi.nlm.nih.gov/pubmed/?term=(((%22plos+one%22%5BJournal%5D)+AND+(genome%5BTitle%2FAbstract%5D+OR+transcriptome%5BTitle%2FAbstract%5D)))+AND+(%222010%22%5BDate+-+Publication%5D+%3A+%222019%22%5BDate+-+Publication%5D)
# ((("plos one"[Journal]) AND (genome[Title/Abstract] OR transcriptome[Title/Abstract]))) AND ("2010"[Date - Publication] : "2019"[Date - Publication]) 
# and save to file as xml
set source plosone
set file source/plosone_source.xml.zst
set result plosone_files.txt
set patterns {
	{href="?(https://doi.org/10.1371/journal.pone.[0-9]+\.s[0-9]*)"?[^\n]*\(XLS}
	{href="?(https://doi.org/10.1371/journal.pone.[0-9]+\.s[0-9]*)"?[^\n]*\(ZIP}
}
mine_pubmed $file $result $patterns
set files plosone_files.txt ; set result plosone_result.txt
scanfiles plosone_files.txt plosone_result.txt
summary plosone_result.txt
# cat plosone_result.txt | cg select -f '{geneerr=if(def($geneerrors,0)>0,1,0)}' -g year -gc 'genelist * geneerr * ucount(id)'

# plos computational biology
# --------------------------
set source ploscompbiol
set result ploscompbiol_result.txt
set mainurl http://journals.plos.org/ploscompbiol
set vols [list_fill 10 6 1]
set issues [list_fill 12 1 1]
set tocs {}
foreach vol $vols year [list_fill 10 2010 1] {
	set toc_urls {}
	foreach iss $issues {
		lappend toc_urls https://journals.plos.org/ploscompbiol/issue?id=10.1371/issue.pcbi.v[format %02d $vol].i[format %02d $iss]
	}
	lappend tocs $year $toc_urls
}
set artpattern {"(https://doi.org/[^"]+)"}
set supppattern {}
set patterns {
	{href="?(https://doi.org/10.1371/journal.pcbi.[0-9]+\.s[0-9]*)"?[^\n]*\(XLS}
	{href="?(https://doi.org/10.1371/journal.pcbi.[0-9]+\.s[0-9]*)"?[^\n]*\(ZIP}
}
mine_toc $source $result $mainurl $tocs $artpattern $supppattern $patterns
summary ploscompbiol_result.txt
# cat ploscompbiol_result.txt | cg select -f '{geneerr=if(def($geneerrors,0)>0,1,0)}' -g year -gc 'genelist * geneerr * ucount(id)'

# dna research
# ------------
set source dnaresearch
set result dnaresearch_result.txt
set mainurl https://academic.oup.com/dnaresearch
set vols [list_fill 10 17 1]
set issues [list_fill 6 1 1]
set tocs {}
foreach vol $vols year [list_fill 10 2010 1] {
	set toc_urls {}
	foreach iss $issues {
		lappend toc_urls $mainurl/issue/$vol/$iss
	}
	lappend tocs $year $toc_urls
}
set artpattern {"(/dnaresearch/article/[^"]+[0-9])"}
set supppattern {}
# file delete {*}[glob ~/tmp/webcache/*dnaresearch_article_*]
mine_toc $source $result $mainurl $tocs $artpattern $supppattern
summary dnaresearch_result.txt
# cat dnaresearch_result.txt | cg select -f '{geneerr=if(def($geneerrors,0)>0,1,0)}' -g year -gc 'genelist * geneerr * ucount(id)'

# overview
# --------

# results per paper
set files [glob *_result.txt]
result_per_paper result_per_paper.tsv {*}$files
result_per_paper result_per_paper-geo.tsv {*}[list_remove $files geo_result.txt]
# make table
cg select -overwrite 1 -g year -gc {has_suppfile * has_genelist * has_error * count} result_per_paper.tsv \
	| cg select -f {
		{-nofile=def($count-0-0-0,0)}
		{-nogenelist=def($count-1-0-0,0)}
		{-noerror=def($count-1-1-0,0)}
		{-xerror=def($count-1-1-1,0)}
		year
		{papers=$nofile + $nogenelist + $noerror + $xerror}
		{files=$nogenelist + $noerror + $xerror}
		{genelist=$noerror + $xerror}
		{error=$xerror}
		{pcterror=if(($noerror + $xerror) > 0,format("%.2f",100.0*$xerror/($noerror + $xerror)),0)}
	} \
| tee overview.tsv

cg select -overwrite 1 -g year -gc {has_suppfile * has_genelist * has_error * count} result_per_paper-geo.tsv \
	| cg select -f {
		{-nofile=def($count-0-0-0,0)}
		{-nogenelist=def($count-1-0-0,0)}
		{-noerror=def($count-1-1-0,0)}
		{-xerror=def($count-1-1-1,0)}
		year
		{papers=$nofile + $nogenelist + $noerror + $xerror}
		{files=$nogenelist + $noerror + $xerror}
		{genelist=$noerror + $xerror}
		{error=$xerror}
		{pcterror=if(($noerror + $xerror) > 0,format("%.2f",100.0*$xerror/($noerror + $xerror)),0)}
	} \
| tee overview-geo.tsv


cg select -q {$year == 2018} result_per_paper.tsv temp
make_summary pct_per_paper_result.tsv.temp temp source
cg select -overwrite 1 -s -pcterror pct_per_paper_summary.tsv.temp pct_per_paper_overview.tsv
file delete pct_per_paper_summary.tsv.temp

# make graph

exec cg cat result_per_paper.tsv \
| cg select -s {has_error source} -q {$has_error} -f {{source=if($source eq "geo","geo","journals")}} -g {year * source * has_error *} \
> for_graph.tsv

set tempfile [tempfile]
file_write $tempfile {
library(ggplot2)
library(grid)
library(gridExtra)
library(gtable)
library(plyr)
d=read.table("for_graph.tsv",header=TRUE,sep="\t")
d=d[d$year < 2019,]
d$year=as.factor(d$year)
d = arrange(d, year, desc(source))
d <- ddply(d, "year", transform, label_ypos=cumsum(count))
d$label_ypos[d$year == 2011 & d$source == "geo"] = 102
p1 = ggplot(d, aes(x = year, y = count, fill = source)) + 
	geom_bar(stat="identity",position = 'stack') +
	geom_text(aes(y=label_ypos, label=count), vjust=1.4, size = 3.5) +
	scale_fill_manual(values=c("grey","darkgrey")) +
	ggtitle("A. Number of papers with errors in supplements") +
	theme_bw()
# ggsave("number_of_errors_per_year.png")

p=read.table("pct_per_paper_overview.tsv",header=TRUE,sep="\t")
p$source = factor(p$source,levels=rev(p$source))
# p$pcterrorp = paste("(",p$error,"/",p$genelist,") ",p$pcterror,"%",sep="")
p$pcterrorp = paste(p$pcterror,"%",sep="")
p$source = mapvalues(p$source,
	from=c("rna", "geo", "genomebiology","genesdev","mbe","nature","genomeresearch","nar","naturegenetics","bmcbioinformatics","bmcgenomics","bioinformatics","plosone","hmg","ploscompbiol","dnaresearch"),
	  to=c("RNA", "GEO", "Genome biol","Genes Dev","Mol Biol Evol","Nature","Genome Res","Nucleic Acids Res","Nat Genet","BMC Bioinformatics","BMC Genomics","Bioinformatics","PLoS One","hmg","PLoS Comp Biol","DNA Res"))

p2 = ggplot(p, aes(x = source, y = pcterror)) + 
	geom_bar(stat="identity",position = 'stack',fill="grey") +
	geom_text(aes(y=pcterror, label=pcterrorp), hjust=-0.1, size = 3.5) +
	ggtitle("B. Percentage of papers with errors in supplements") +
	coord_flip() +
	theme_bw()
# ggsave("pct_errors_per_journal_2018.png")

g <- arrangeGrob(p1, p2, nrow=1)
ggsave(file="Fig1.png", g)

}

exec Rscript $tempfile

# make percentages graph
