# Simple Chromium Updater (chrupd.cmd)

#### Self executable PowerShell script to auto update Chromium for Windows

Uses RSS feed from https://chromium.woolyss.com to download and install latest Chromium version, if a newer version is available. Options can be set in script or using command line arguments (try "`chrupd.cmd -h`")

 - default is to get the "stable" 64-bit "nosync" Installer by "Nik"
 - verifies sha1/md5 hash and runs installer

If you add a scheduled task with "-crTask", a vbs wrapper is written to **chrupd.vbs** which is used to hide it's window.
Use "-noVbs" to disable, this will however cause a flashing window when the task runs.

*For easy execution this PowerShell script is embedded in a Batch .CMD file using a "polyglot wrapper". It can be renamed to chrupd.ps1. More info: [blogs.msdn.microsoft.com](https://blogs.msdn.microsoft.com/jaybaz_ms/2007/04/26/powershell-polyglot) and [stackoverflow.com](https://stackoverflow.com/questions/29645).*

Note that this script has no connection to the preexisting [ChrUpdWin.cmd](https://gist.github.com/mikhaelkh/12dec36d4a1c4136628b#file-chrupdwin-cmd) Batch file by [Michael Kharitonov](https://github.com/mikhaelkh)</small>

---

<pre>

USAGE: chrupd.cmd -[editor|channel|getFile|force]
                  -[crTask|rmTask|shTask|noVbs|confirm]

         -editor  can be set to [Nik|RobRich|Chromium]
         -channel can be set to [stable|dev]
         -getFile can be set to [chromium-sync.exe|chromium-nosync.exe]
         -force   always (re)install latest version

         -crTask  to create a daily scheduled task
         -rmTask  to remove scheduled task
         -shTask  to show scheduled task details
         -noVbs   to not use vbs wrapper to hide window when creating task
         -confirm to answer Y on prompt about removing scheduled task

EXAMPLE: .\chrupd.cmd -editor Nik -channel stable -getFile chromium-nosync.exe
                      [-crTask]

NOTES:   - Options are CasE Sensive
         - Option "getFile" is only used if editor is set to "Nik"
         - Options "xxTask" can also be used without any other options
         - Options can be set permanently using variables inside script
         
</pre>