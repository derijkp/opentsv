# make executable with correct resources and put in tca (windows)
. /opt/crosstool/cross-compat-mingw32msvc.sh
cd ~/dev/opentsv/win/rc
rm -f opentsv.exe version.res
cp ~/build/tca/Windows-intel/wish*.exe opentsv.exe
PATH=$CROSSBIN:$PATH i386-mingw32msvc-windres -i version.rc -o version.res -O res
wine ~/.wine/drive_c/Program\ Files\ \(x86\)//Resource\ Hacker/ResourceHacker.exe -modify opentsv.exe,opentsv.exe,opentsv.ico,ICONGROUP,APP,1033
wine ~/.wine/drive_c/Program\ Files\ \(x86\)/Resource\ Hacker/ResourceHacker.exe -modify opentsv.exe,opentsv.exe,version.res,versioninfo,1,
# wine ~/.wine/drive_c/Program\ Files/Resource\ Hacker/ResHacker.exe opentsv.exe
mv opentsv.exe ~/build/tca/Windows-intel
