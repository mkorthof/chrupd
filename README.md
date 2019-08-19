# Simple Chromium Updater / chrupd.cmd

#### *Self executable PowerShell script to auto update Chromium for Windows*

Uses RSS feed from https://chromium.woolyss.com to download and install latest Chromium version, if a newer version is available. Options can be set in script or using command line arguments ( try `chrupd.cmd -h` )

 - default is to get the "stable" 64-bit ("sync") Installer by "Nik"
 - verifies SHA1/MD5 hash and runs installer

### Changes:

Moved to [CHANGES.md](CHANGES.md)

### Configuration:

Make sure the combination of editor and channel is correct. You can also use  the ```list``` option. For more information about versions check: [chromium.woolyss.com](https://chromium.woolyss.com/?cut=1&ago=1) (RSS atom [feed](https://chromium.woolyss.com/feed/windows-64-bit)).

| Editor       | Channel      |
|:-------------|:-------------|
| Nik          | stable, dev  |
| RobRich      | dev          |
| Chromium     | dev          |
| ThumbApps    | dev          |


### Scheduled Task:

You can add a Scheduled Task with ```crTask```. A VBS wrapper will be written to **chrupd.vbs** which is used to hide it's window. Option ```noVbs``` disables the wrapper, this will however cause a flashing window when the task runs.

### Updating:

To update Simple Chromium Updater to a newer version just replace "chrupd.cmd" (copy "editor" and "channel" if set). If you have Scheduled Task setup you do not need to change the task. 

---

*For easy execution this PowerShell script is embedded in a Batch .CMD file using a "polyglot wrapper". It can be renamed to chrupd.ps1. More info: [blogs.msdn.microsoft.com](https://blogs.msdn.microsoft.com/jaybaz_ms/2007/04/26/powershell-polyglot) and [stackoverflow.com](https://stackoverflow.com/questions/29645).*
 
<small>*Note that this script has no connection to the preexisting [ChrUpdWin.cmd](https://gist.github.com/mikhaelkh/12dec36d4a1c4136628b#file-chrupdwin-cmd) Batch file by [Michael Kharitonov](https://github.com/mikhaelkh)*</small>

---

### Command Line Options:

<pre>

USAGE: chrupd.cmd -[editor|channel|autoUpd|force|getVer|list]
                  -[taskMode|crTask|rmTask|shTask|noVbs|confirm]

         -editor  can be set to <Nik|RobRich|Chromium|ThumbApps>
         -channel can be set to <stable|dev>
         -force   always (re)install, even if latest Chromium is installed
         -getVer  lists currently installed Chromium version
         -list    lists editors website, repository and installer

         -tsMode  can be set to <1|2|3> or "auto" if unset, details below
         -crTask  to create a daily scheduled task
         -rmTask  to remove scheduled task
         -shTask  to show scheduled task details
         -noVbs   to not use vbs wrapper to hide window when creating task
         -confirm to answer Y on prompt about removing scheduled task

EXAMPLE: .\chrupd.cmd -editor Nik -channel stable [-crTask]

NOTES:   - Options "editor" and "channel" need an argument (CasE Sensive)
         - Option "tsMode" task scheduler modes: unset Default=Auto(Detect OS),
             or: 1=Normal(Windows8+), 2=Legacy(Win7), 3=Command(WinXP)
         - Schedule "xxTask" options can also be used without any other options
         - Options can be set permanently using variables inside script

</pre>
