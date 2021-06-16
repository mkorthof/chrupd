'
' Wrapper for chrupd.cmd to hide window when using Task Scheduler
'
Dim WinScriptHost
For i = 0 to (WScript.Arguments.Count - 1)
Args = Args & " " & WScript.Arguments(i)
Next
Set WinScriptHost = CreateObject("WScript.Shell")
WinScriptHost.Run Chr(34) & "C:\Users\silver\dev\chrupd\test\chrupd.ps1" & Chr(34) & " " & Args, 0
Set WinScriptHost = Nothing
