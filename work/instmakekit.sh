#!/bin/bash
export opentsvdir=/home/peter/dev/opentsv
export kitdir=/home/peter/dev/opentsv/kit
echo "---------- Make opentsv kit ----------"
cd $kitdir
cp $opentsvdir/opentsv.tcl $opentsvdir/res/tclkit.inf opentsv.vfs
echo '' > $kitdir/opentsv.vfs/MANIFEST
cd $kitdir
rm opentsv.exe || true
wine tclkit858.exe sdx-20110317.kit wrap opentsv.exe -runtime tclkit-win32.upx.exe

cd ~/dev/opentsv
cp -f kit/opentsv.exe ~/move/com
cp -f kit/opentsv.exe /home/peter/build/tca/Windows-intel/opentsv.exe
cp -f opentsv.tcl ~/move/com

# cp -f /home/peter/dev/opentsv/opentsv.tcl ~/move/tca/Windows-intel/apps/opentsv/
# cp -f ~/move/tca/Windows-intel/apps/opentsv/opentsv.tcl /home/peter/dev/opentsv
