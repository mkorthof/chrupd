@echo off
REM :: CI: %psExe% -Command 'Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Confirm:$false -Force;
REM ::                       Invoke-ScriptAnalyzer -Path chrupd.ps1 -ExcludeRule PSAvoidUsingWriteHost,PSAvoidUsingInvokeExpression -EnableExit'
SETLOCAL
FOR %%a IN ( "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe", "C:\Program Files\PowerShell\6\pwsh.exe", "C:\Program Files\PowerShell\7\pwsh.exe" ) DO (
    IF EXIST "%%~a" (
        SET "psExe=%%~a"
    )
)
cd ..
SET /A RUN=0
SET /A ANALYZE=0
IF /I "%~1" == ""  ( SET RUN=1 & SET ANALYZE=1 )
IF /I "%~1" == "-a" ( SET RUN=1 & SET ANALYZE=1 )
IF /I "%~1" == "-r" ( SET RUN=1 )
IF /I "%~1" == "-p" ( SET ANALYZE=1)

IF %RUN% EQU 1 (
  echo:
  echo Running script and checking logs...
  echo:
  %psExe% -File chrupd.ps1 || true
   grep "Latest Chromium version already installed\|New Chromium version\|Done\." chrupd.log
 )

IF %ANALYZE% EQU 1 (
  echo:
  echo Running PSScriptAnalyzer...
  echo:
  %psExe% -Command Invoke-ScriptAnalyzer -Path chrupd.ps1 -ExcludeRule PSAvoidUsingWriteHost,PSAvoidUsingInvokeExpression
)
ENDLOCAL