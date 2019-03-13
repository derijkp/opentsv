#!/bin/bash
script="$(readlink -f "$0")"
opentsvdir="$(dirname "$script")"
export kitdir=$opentsvdir/kit

echo "---------- Make opentsv kit ----------"
cd $kitdir
cp $opentsvdir/opentsv.tcl $opentsvdir/res/tclkit.inf opentsv.vfs
echo '' > $kitdir/opentsv.vfs/MANIFEST
cd $kitdir
rm opentsv.exe || true
wine tclkit858.exe sdx-20110317.kit wrap opentsv.exe -runtime tclkit-win32.upx.exe
echo "kit/opentsv.exe built"
