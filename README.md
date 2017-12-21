# Simple Chromium Updater (chrupd.cmd)

Uses RSS feed from "chromium.woolyss.com" to download and install latest Chromium version, if a newer version is available. Options can be set in script or using command line arguments (try "chrupd.cmd -h")

 - default is to get the "stable" 64-bit "nosync" Installer by "Nik"
 - verifies sha1/md5 hash and runs installer
 
NOTE: for easy execution this PowerShell script is embedded in a Batch .CMD file using a "polyglot wrapper". It can be renamed to chrupd.ps1. More info:

   - https://blogs.msdn.microsoft.com/jaybaz_ms/2007/04/26/powershell-polyglot
   - https://stackoverflow.com/questions/29645
   
```
USAGE: chrupd.cmd -[editor|channel|getFile]

         -editor  can be set to [Nik|RobRich|Chromium]
         -channel can be set to [stable|dev]
         -getFile can be set to [chromium-sync.exe|chromium-nosync.exe]

EXAMPLE: chrupd.cmd -editor Nik -channel stable -getFile chromium-nosync.exe
```

- Option "getFile" is only used if editor is set to "Nik"
- Settings are Case Sensive
- Options can also be set permanently using variables inside script
