export opentsvdir=/home/peter/dev/opentsv
export kitdir=/home/peter/dev/opentsv/kit
echo "---------- Make opentsv kit ----------"
cd $kitdir
cp $opentsvdir/opentsv.tcl $opentsvdir/res/tclkit.inf opentsv.vfs
echo '' > $kitdir/opentsv.vfs/MANIFEST
cd $kitdir
rm opentsv.exe
wine tclkit858.exe sdx-20110317.kit wrap opentsv.exe -runtime tclkit-win32.upx.exe
cp -f opentsv.exe ~/move/com
cp -f opentsv.exe /home/peter/build/tca/Windows-intel/opentsv.exe

