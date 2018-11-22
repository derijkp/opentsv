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
Download the binary opentsv release:
[opentsv](https://github.com/derijkp/opentsv/releases/download/v1.0/opentsv.exe)
Starting the downloaded program without a file gives you this
settings/installation screen. This program does not have to be installed:
You can use it directly by using the "Open file" or by dragging a file
onto the exe. However, if you install it and/or register it as the default
program to open tsv and csv files (bottom), its use becomes transparent:
double clicking a tsv file will open it in Excel with the current
settings.

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

Copyright (c) 2017 Peter De Rijk (VIB - University of Antwerp Center for Molecular Neurology)
Available under MIT license
