@echo off
REM :: CI: %psExe% -Command 'Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Confirm:$false -Force;
REM ::                       Install-Module -Name Pester -Scope CurrentUser -Confirm:$false -Force -SkipPublisherCheck
REM ::                       Install-Module -Name ImportTestScript -Scope CurrentUser -Confirm:$false -Force -SkipPublisherCheck
REM ::                       Invoke-ScriptAnalyzer -Path chrupd.ps1 -ExcludeRule PSAvoidUsingWriteHost,PSAvoidUsingInvokeExpression -EnableExit;
REM ::                       Invoke-Pester'
IF NOT EXIST .\chrupd.ps1 (
  echo Run from git repo dir, exiting...
  EXIT /B
)
SET /A BROKEN_LINK=0
FOR %%i IN ("chrupd.ps1") DO (
  SET attribs=%%~ai
)
IF NOT "%attribs:~-3%" == "l--" (
  SET /A BROKEN_LINK=1
)
( findstr -r "^chrupd.cmd$" chrupd.ps1 >nul 2>&1 ) && SET /A BROKEN_LINK=1
IF %BROKEN_LINK% EQU 1 (
  echo Link chrupd.ps1 broken
  EXIT /B
)
SETLOCAL
FOR %%a IN ( "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe", "C:\Program Files\PowerShell\6\pwsh.exe", "C:\Program Files\PowerShell\7\pwsh.exe" ) DO (
    IF EXIST "%%~a" (
        SET "psExe=%%~a"
    )
)
SET /A RUN=0
SET /A ANALYZE=0
SET /A PESTER=1
IF /I "%~1" == ""  ( SET RUN=1 & SET ANALYZE=1 & SET PESTER=1 )
IF /I "%~1" == "-a" ( SET RUN=1 & SET ANALYZE=1 & SET PESTER=1 )
IF /I "%~1" == "-r" ( SET RUN=1 )
IF /I "%~1" == "-p" ( SET ANALYZE=1 & SET PESTER=0 )
IF /I "%~1" == "-e" ( SET PESTER=1 )

IF %RUN% EQU 1 (
  echo:
  echo Running script and checking logs...
  echo:
  IF EXIST "test\chrupd.log" (
    del /f /q test\chrupd.log
  )
  REM :: %psExe% -File chrupd.ps1 -debug 3  || true
  %psExe% .\chrupd.ps1 -debug 3 || true
  %psExe% -Command "Get-Content -Path chrupd.log -Tail 4|Select-String -Pattern 'Latest Chromium version already installed|New Chromium version|Done\.'"
 )

IF %ANALYZE% EQU 1 (
  echo:
  echo Running PSScriptAnalyzer...
  echo:
  %psExe% -Command Invoke-ScriptAnalyzer -Path .\chrupd.ps1 -ExcludeRule PSAvoidUsingWriteHost,PSAvoidUsingInvokeExpression,PSUseShouldProcessForStateChangingFunctions
)

IF %PESTER% EQU 1 (
  echo:
  echo Running Pester...
  echo:
  %psExe% -Command Invoke-Pester
)
ENDLOCAL