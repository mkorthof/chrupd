# Simple Chromium Updater (chrupd.cmd)

Uses RSS feed from https://chromium.woolyss.com to download and install latest Chromium version, if a newer version is available. Options can be set in script or using command line arguments (try "chrupd.cmd -h")

 - default is to get the "stable" 64-bit "nosync" Installer by "Nik"
 - verifies sha1/md5 hash and runs installer
 
For easy execution this PowerShell script is embedded in a Batch .CMD ile using a "polyglot wrapper". It can be renamed to chrupd.ps1. More info:
 - https://blogs.msdn.microsoft.com/jaybaz_ms/2007/04/26/powershell-polyglot
 - https://stackoverflow.com/questions/29645

If you add a scheduled task with "-crTask", a vbs wrapper is written to **chrupd.vbs** which is used to hide it's window.
Use "-noVbs" to disable, this will cause a flashing window when the task runs.

```
USAGE: chrupd.cmd -[editor|channel|getFile]|[crTask|rmTask|shTask|noVbs|confirm]

         -editor  can be set to [Nik|RobRich|Chromium]
         -channel can be set to [stable|dev]
         -getFile can be set to [chromium-sync.exe|chromium-nosync.exe]

         -crTask to create a daily scheduled task
         -rmTask to remove scheduled task
         -shTask to show scheduled task details
         -noVbs to not use vbs wrapper to hide window when creating task
         -confirm to answer Y on prompt about removing scheduled task

EXAMPLE: .\chrupd.cmd -editor Nik -channel stable -getFile chromium-nosync.exe
                      [-crTask]

NOTES:   - Options are Case Sensive
         - Option "getFile" is only used if editor is set to "Nik"
         - Options "xxTask" can also be used without any other options
         - Options can be set permanently using variables inside script
```
