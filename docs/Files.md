# Files

Description of all files included in repo, and used by script

## Batch: chrupd.cmd

To make this script self executable a "polyglot wrapper" or "header" with batch commands has been added. This makes sure the script can be started from GUI, cmd.exe and PowerShell.

Basicly what it does is start powershell.exe and run the contents of the file as ScriptBlock. Also arguments are 'handed over' to PS. It will skip the header because it's a comment.

More details about this method can be found here:

- [https://blogs.msdn.microsoft.com/jaybaz_ms/2007/04/26/powershell-polyglot](https://blogs.msdn.microsoft.com/jaybaz_ms/2007/04/26/powershell-polyglot)
- [https://stackoverflow.com/q/29645](https://stackoverflow.com/q/29645)

## PowerShell: chrupd.ps1

The script can be renamed to `chrupd.ps1`. Now you can run it as a normal PowerShell script e.g. `.\chrupd.ps1` and `powershell.exe chrupd1.ps1` or `pwsh.exe chrupd.ps1`. 

If you plan on using it only from PS (or if theres issues) the first few lines of the script can be removed. These are a multi line PS comment `<# ... #>`

``` cmd
<# :
@echo off & SETLOCAL & SET "_PS=powershell.exe -NoLogo -NoProfile" & SET "_ARGS=\"%~dp0" %*"
%_PS% "&(Invoke-Command {[ScriptBlock]::Create('$Args=@(&{$Args} %_ARGS%);'+((Get-Content \"%~f0\") -Join [char]10))})"
ENDLOCAL & GOTO :EOF
#>
```

You might have to change PS Execution Policy (see `Get-Help about_Execution_Policies`)

Instead of renaming, the .ps1 file can also be [symlink](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/mklink), which it is by default in the GitHub repo.

## Executable: chrupd.exe

TODO

~~The script is also converted to standalone executable using [PS2EXE](https://github.com/MScholtes/PS2EXE).~~

~~It might be somewhat slower.~~

## Logs: chrupd.log

Logs go to 'chrupd.log', as defined by `$logFile` variable. Default path is same dir as script.

If the file is not writable the script will let you know and output to console only.

The Chromium installer will separately log to 'chromium_installer.log' in TEMP dir as defined by `$installLog`.

## Archives

Usually Chromium installation is automatically taken care of by running the downloaded Installer ('mini_installer.exe').

But if Chromium is released as a zip or 7z archive, the script will to try to extract it to these paths:

| Path                                   | Example                                   |
|:---------------------------------------|:------------------------------------------|
| %LocalAppData%\Chromium\Application    | C:\Users\\<User\>\Appdata\Local\Chromium  |
| Desktop                                | C:\Users\\<User\>\Desktop                 |
| %TEMP%                                 | C:\Users\\\<User\>\TEMP                   |

( _in that order, top to bottom_ )

The folder that was used will be shown and a shortcut will be created on the Desktop called 'Chromium', which links to chrome.exe. Install paths are defined with script variable `$archiveInstallPaths`.

Related [advanced options](/docs/Options.md) are: `appDir` and `linkArgs`

### 7-zip

If '7z.exe' from 7-Zip cannot be found the script will try to automatically download '7za.exe' which is a standalone version of 7-Zip.
The file will be downloaded from: 7zip.org, github-chromium, googlesource.com or chocolatey.org. 

Paths and urls are defined in script variable `7zConfig`.

More information about 7zip cli:

- [https://www.7-zip.org/history.txt](https://www.7-zip.org/history.txt)
- [https://sourceforge.net/p/sevenzip/discussion/45798/thread/b599cf02/?limit=25](https://sourceforge.net/p/sevenzip/discussion/45798/thread/b599cf02/?limit=25)

## Windows Defender

It seems the script gets detected as false positive sometimes: 'Trojan:PowerShell/Mountsi.A!ml' (amsi).

You could add an exception by using the Allow action in Windows Security, ofcourse always check the script first.

Another workaround is to remove the batch/ps1 polyglot header.

More information:

- [https://www.microsoft.com/en-us/wdsi/threats/malware-encyclopedia-description?Name=Trojan:O97M/Mountsi.A!ml](https://www.microsoft.com/en-us/wdsi/threats/malware-encyclopedia-description?Name=Trojan:O97M/Mountsi.A!ml)
- [https://docs.microsoft.com/en-us/windows/win32/amsi/how-amsi-help](https://docs.microsoft.com/en-us/windows/win32/amsi/how-amsi-help)
