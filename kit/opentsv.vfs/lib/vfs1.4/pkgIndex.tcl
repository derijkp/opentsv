
      package ifneeded vfs 1.4 "load {} vfs; source \[file join [list $dir] vfsUtils.tcl\]; source \[file join [list $dir] vfslib.tcl\]"
  
package ifneeded starkit 1.3.3 [list source [file join $dir starkit.tcl]]
package ifneeded vfs::mk4     1.10.1 [list source [file join $dir mk4vfs.tcl]]
package ifneeded vfs::zip     1.0.3  [list source [file join $dir zipvfs.tcl]]
package ifneeded vfs::tar     0.91 [list source [file join $dir tarvfs.tcl]]
