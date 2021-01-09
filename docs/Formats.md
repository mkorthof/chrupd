# File Formats

## Batch: chrupd.cmd

To make this script self executable a "polyglot wrapper" or "header" with batch commands has been added. This makes sure the script can be started from GUI, cmd.exe and PowerShell.

Basicly what it does is start powershell.exe and run the contents of the file as ScriptBlock. Also arguments are 'handed over' to PS. It will skip the header because it's a comment.

More details about this method can be found here:

- [https://blogs.msdn.microsoft.com/jaybaz_ms/2007/04/26/powershell-polyglot](https://blogs.msdn.microsoft.com/jaybaz_ms/2007/04/26/powershell-polyglot)
- [https://stackoverflow.com/q/29645](https://stackoverflow.com/q/29645)

## PowerShell: chrupd.ps1

The script can be renamed to `chrupd.ps1`. Now you run it as a normale PowerShell script e.g. `.\chrupd.ps1` and `powershell.exe chrupd1.ps1`.

If you plan on using it only from PS (or if theres issues) the first few lines of the script can be removed. These are a multi line PS comment `<# ... #>`

``` cmd
<# :
@echo off & SETLOCAL & SET "_PS=powershell.exe -NoLogo -NoProfile" & SET "_ARGS=\"%~dp0" %*"
%_PS% "&(Invoke-Command {[ScriptBlock]::Create('$Args=@(&{$Args} %_ARGS%);'+((Get-Content \"%~f0\") -Join [char]10))})"
ENDLOCAL & GOTO :EOF
#>
```

You might have to change PS Execution Policy (see `Get-Help about_Execution_Policies`)

## Executable: chrupd.exe (TODO)

~~The script is also converted to standalone executable using [PS2EXE](https://github.com/MScholtes/PS2EXE).~~

~~It might be somewhat slower.~~

## Windows Defender

It seems the script gets detected as false positive sometimes: 'Trojan:PowerShell/Mountsi.A!ml' (amsi).

You could add an exception by using the Allow action in Windows Security, ofcourse always check the script first.

Another workaround is to remove the batch/ps1 polyglot header.

More information:

- [https://www.microsoft.com/en-us/wdsi/threats/malware-encyclopedia-description?Name=Trojan:O97M/Mountsi.A!ml](https://www.microsoft.com/en-us/wdsi/threats/malware-encyclopedia-description?Name=Trojan:O97M/Mountsi.A!ml)
- [https://docs.microsoft.com/en-us/windows/win32/amsi/how-amsi-help](https://docs.microsoft.com/en-us/windows/win32/amsi/how-amsi-help)
