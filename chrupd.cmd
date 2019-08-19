<# :
@echo off
SETLOCAL & SET "PS_BAT_ARGS=\""%~dp0|"\" %*"
ENDLOCAL & powershell.exe -NoLogo -NoProfile -Command "&(Invoke-Command {[ScriptBlock]::Create('$Args = @( &{$Args} %PS_BAT_ARGS%" );'+[String]::Join([char]10,(Get-Content \"%~f0\")))})"
GOTO :EOF
#>

<# ------------------------------------------------------------------------- #>
<# 20190126 MK: Simple Chromium Updater (chrupd.cmd)                         #>
<# ------------------------------------------------------------------------- #>
<# Uses RSS feed from "chromium.woolyss.com" to download and install latest  #>
<# Chromium version, if a newer version is available. Options can be set     #>
<# below or using command line arguments (try "chrupd.cmd -h")               #>
<#  - default is to get the "stable" 64-bit "nosync" Installer by "Nik"      #>
<#  - verifies sha1/md5 hash and runs installer                              #>
<# ------------------------------------------------------------------------- #>
<# NOTES:                                                                    #>
<# - If you add a scheduled task with -crTask, a VBS wrapper is written to   #>
<#   chrupd.vbs which is used to hide it's window. use -noVbs to disable.    #>
<# - To update chrupd to a newer version just replace this .cmd file.        #>
<# ------------------------------------------------------------------------- #>
<# For easy execution this PowerShell script is embedded in a Batch .CMD     #>
<# file using a "polyglot wrapper". Renaming to .ps1 also works. More info:  #>
<#  - https://blogs.msdn.microsoft.com/jaybaz_ms/2007/04/26                  #>
<#  - https://stackoverflow.com/questions/29645                              #>
<# ------------------------------------------------------------------------- #>

<# ------------------------------------------------------------------------- #>
<# CONFIGURATION:                                                            #>
<# Make sure the combination of editor and channel is correct                #>
<# See "chrupd.cmd -h" or README.md for more possible settings               #>
<# ------------------------------------------------------------------------- #>
<# 2018-08-09: Nik's nosync builds are no longer available, more info:       #>
<#             https://chromium.woolyss.com/#news                            #>
<# ------------------------------------------------------------------------- #>

$editor = "Nik"
$channel = "stable"
$log = 1

<# END OF CONFIGURATION ---------------------------------------------------- #>

$Args = $Args -Replace '\|', ''
$autoUpd = 0
$scriptDir = $Args[0]
If ( $(Try { (Test-Path variable:local:scriptDir) -And	(&Test-Path $scriptDir -ErrorAction Ignore -WarningAction Ignore) -And
			 (-Not [string]::IsNullOrWhiteSpace($scriptDir)) } Catch { $False }) ) {
	$rm = ($Args[0]); $Args = ($Args) | Where-Object { $_ -ne $rm }
} Else {
	$scriptDir = ($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.\'))
}

$logFile = $scriptDir + "\chrupd.log"
$scriptName = "Simple Chromium Updater"; $scriptCmd = "chrupd.cmd"
$installLog = "$env:TEMP\chromium_installer.log"
$checkSite = "chromium.woolyss.com"
$rssFeed = "https://$checkSite/feed/windows-64-bit"

$debug = $fakeVer = $force = $ignVer = $ignHash = 0
$tsMode = $crTask = $rmTask = $shTask = $xmlTask = $manTask = $noVbs = $confirm = 0
$scheduler = $getVer = $list = 0

$items = @{
	"Nik" = @("https://$checkSite", "https://github.com/henrypp/chromium/releases/download/", "chromium-sync.exe");
	"RobRich" = @("https://$checkSite", "https://github.com/RobRich999/Chromium_Clang/releases/download/", "mini_installer.exe");
	"Chromium" =  @("https://www.chromium.org", "https://storage.googleapis.com/chromium-browser-snapshots/Win_x64/", "mini_installer.exe");
	"The Chromium Authors" =  ($items.("Chromium"));
	"ThumbApps" = @("http://www.thumbapps.org", "https://netix.dl.sourceforge.net/project/thumbapps/Internet/Chromium/", "ChromiumPortable_");
}

<#
  "Windows Version" = @(majorVer, minorVer, osType[1=ws,3=server], tsMode)
#>
$windowsVersions = @{
	"Windows 10" 				= @(10, 0, 1, 1);
	"Windows 8.1" 				= @( 6, 3, 1, 1);
	"Windows 8" 				= @( 6, 2, 1, 1);
	"Windows 7" 				= @( 6, 1, 1, 2);
	"Windows Vista" 			= @( 6, 0, 1, 2);
	"Windows XP 64bit"			= @( 5, 2, 1, 3);
	"Windows XP" 				= @( 5, 1, 1, 3);
	"Windows Server 2019" 		= @(10, 0, 3, 1);
	"Windows Server 2016" 		= @(10, 0, 3, 1);
	"Windows Server 2012 R2" 	= @( 6, 3, 3, 1);
	"Windows Server 2012" 		= @( 6, 2, 3, 1);
	"Windows Server 2008 R2"	= @( 6, 1, 3, 2);
	"Windows Server 2008" 		= @( 6, 0, 3, 2);
	"Windows Server 2003" 		= @( 5, 2, 3, 3);
}
$osTypeList = @{
	1 = "Workstation";
	2 = "DC";
  3 = "Server";
}
$tsList = @{
	0 = "Auto";
	1 = "Normal";
	2 = "Legacy";
	3 = "Schtasks Command"
}

Write-Host -ForeGroundColor White -NoNewLine "`r`n$scriptName"; Write-Host " ($scriptCmd)"; Write-Host ("-" * 36)"`r`n"

<# TODO: selfupdater
- (!) retain user settings/vars from current version
- get SHA from gh:
	GET /repos/:owner/:repo/contents/:path
	GET /repos/<owner>/<repo>/git/trees/url_encode(<branch_name>:<parent_path>)
	e.g. https://api.github.com/repos/libgit2/libgit2sharp/git/trees/master:Lib%2FMoQ
#>
$autoUpd = 1
If ($Args -iMatch "-testUpd") {
	Write-Host "DEBUG: Uncomment to test selfupdater"
	Return
  If ($autoUpd -eq 1) {
  	$loBlob = "blob $((Get-Item $scriptCmd).Length)`0" + $(Get-Content "$scriptCmd"|Out-string)
	#TEST: $scriptCmd = "README.md"; $loblob = "blob $((Get-Item ${scriptDir}$scriptCmd).Length)`0" + Get-Content "${scriptDir}$scriptCmd"
  	$loSha = (Get-FileHash -Algorithm SHA1 -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes((($loBlob)))))).Hash
    [System.Net.ServicePointManager]::SecurityProtocol = @("Tls12","Tls11","Tls")
  	$ghApi = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("aHR0cHM6Ly9hcGkuZ2l0aHViLmNvbS9yZXBvcy9ta29ydGhvZi9jaHJ1cGQvY29udGVudHMvY2hydXBkLmNtZA=="))
  	$ghJson = (ConvertFrom-Json(Invoke-WebRequest -UseBasicParsing -TimeoutSec 300 -Uri $ghApi))
    #$ghContent = ($ghJson).content
  	#$ghTmp  = [System.Text.Encoding]::UTF8.GetBytes.(($ghJson).content)
  	#$ghStr = [System.Convert]::ToBase64String($ghTmp)
    #$ghTmp = [System.Text.Encoding]::UTF8.GetString(([System.Convert]::FromBase64String((($ghJson).content))|?{$_}))
  	$ghContent = [System.Text.Encoding]::UTF8.GetString(([System.Convert]::FromBase64String((($ghJson).content))))

    $ghSha = (($ghJson).sha).ToUpper()
  	Write-Host "DEBUG: loSha=" $loSha
  	Write-Host "DEBUG: ghSha=" $ghSha
  	If ($loSha -ne $ghSha) {
  		Write-Host "Update available:"
  		If ( $(Try { (&Test-Path ${scriptCmd}.tmp) } Catch { $False }) ) {
  			Write-Host "DEBUG: TEMP ${scriptCmd}.tmp already exists, removing..."
  			Try {
					Remove-Item -ErrorAction Stop -WarningAction Stop ${scriptCmd}.tmp -Force
				} Catch { 
					$eMsg = "ERROR: Could not remove ${scriptCmd}.tmp"
					Write-Host -ForeGroundColor Red "$eMsg" "`r`n";	Write-Log "$eMsg"
					Return
				}
  		}
  		$ghContent | Set-Content -NoNewline "${scriptCmd}.tmp"
  		Get-Item "${scriptCmd}.tmp"
  		#((Get-FileHash -Algorithm SHA1 "${scriptCmd}.tmp").Hash).ToLower()
  		$newBlob = "blob $((Get-Item "${scriptCmd}.tmp").Length)`0" + $(Get-Content "${scriptCmd}.tmp"|Out-string)
  		$newSha = (Get-FileHash -Algorithm SHA1 -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes((($newBlob)))))).Hash
  		#Write-Host "DEBUG: newBLow=$newBlob"
  		Write-Host "DEBUG: TEMP ghSha=$ghSha"
  		Write-Host "DEBUG: TEMP newSha=$newSha"
  		If ($ghSha -eq $newSha) {
  			Write-Host "Local file matches GitHub SHA1 Hash, renaming current version `"${scriptCmd}`" to `"$scriptCmd.bak`" first"
  			Try {
					#Rename-Item -Force -Verbose -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Path "${scriptCmd}.tmp" -NewName "${scriptCmd}.TEST" } Catch { ErrorMessage "Could not rename $scriptCmd" };
					Move-Item -Force -Verbose -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Path "${scriptCmd}" -Destination "${scriptCmd}.bak.TEST"
				} Catch {
					$eMsg = "ERROR: Could not move ${scriptCmd} to $scriptCmd.bak"
					Write-Host -ForeGroundColor Red "$eMsg" "`r`n";	Write-Log "$eMsg"
					Return
				}
  			Write-Host "Copying new version `"${scriptCmd}.tmp`" to `"$scriptCmd`""
  			Try {
					Move-Item -Force -Verbose -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Path "${scriptCmd}.tmp" -Destination "${scriptCmd}.TEST"
				} Catch {
					$eMsg = "ERROR: Could not move ${scriptCmd}.tmp to $scriptCmd"
					Write-Host -ForeGroundColor Red "$eMsg" "`r`n";	Write-Log "$eMsg"
					Return
				};
    	} Else {
  			Write-Host "ERROR: Local file SHA1 Hash does not match GitHub's"
				Return
  		}
  	} 
    Exit
  }
}

<# SHOW HELP AND ARGUMENTS #>
<# REMOVED: Options related to Nik's nosync build #>
If ($Args -iMatch "[-/]h") {
	Write-Host "Uses RSS feed from `"$checkSite`" to download and install latest"
	Write-Host "Chromium version, if a newer version is available.", "`r`n"
	Write-Host "USAGE: $scriptCmd -[editor|channel|autoUpd|force|getVer|list]"
	Write-Host "`t`t", " -[taskMode|crTask|rmTask|shTask|noVbs|confirm]", "`r`n"
	Write-Host "`t", "-editor  can be set to <Nik|RobRich|Chromium|ThumbApps>"
	Write-Host "`t", "-channel can be set to <stable|dev>"
<# Write-Host "`t" "-getFile can be set to [chromium-sync.exe|chromium-nosync.exe]" #>
<# Write-Host "`t", "-autoUpd can set to <0|1> to turn off|on auto updating $scriptCmd" #>
	Write-Host "`t", "-force   always (re)install, even if latest Chromium is installed"
	Write-Host "`t", "-getVer  lists currently installed Chromium version"
	Write-Host "`t", "-list    lists editors website, repository and installer", "`r`n"
	Write-Host "`t", "-tsMode  can be set to <1|2|3> or `"auto`" if unset, details below"
	Write-Host "`t", "-crTask  to create a daily scheduled task"
	Write-Host "`t", "-rmTask  to remove scheduled task"
	Write-Host "`t", "-shTask  to show scheduled task details"
	Write-Host "`t", "-noVbs   to not use vbs wrapper to hide window when creating task"
	Write-Host "`t", "-confirm to answer Y on prompt about removing scheduled task", "`r`n"
<# Write-Host "`t" "-ignVer  (!) ignore version mismatch between feed and filename" "`r`n" #>
<# Write-Host "EXAMPLE: .\$scriptCmd -editor Nik -channel stable -getFile chromium-nosync.exe #>
<# Write-Host "EXAMPLE: .\$scriptCmd -editor Nik -channel stable [-autoUpd 1] [-crTask]", "`r`n" #>
	Write-Host "EXAMPLE: .\$scriptCmd -editor Nik -channel stable [-crTask]", "`r`n"
	Write-Host "NOTES:   - Options `"editor`" and `"channel`" need an argument (CasE Sensive)"
<# Write-Host "`t" "Option `"getFile`" is only used if editor is set to `"Nik`"" #>
	Write-Host "`t", "- Option `"tsMode`" task scheduler modes: default/unset Auto(Detect OS),"
	Write-Host "`t", "    or: 1=Normal(Windows8+), 2=Legacy(Win7), 3=Command(WinXP)"
	Write-Host "`t", "- Schedule `"xxTask`" options can also be used without any other options"
	Write-Host "`t", "- Options can be set permanently using variables inside script", "`r`n"
	Exit 0
} Else {
	ForEach ($a in $Args) {
		$p = "[-/](debug|force|fakeVer|getVer|list|crTask|rmTask|shTask|xmlTask|manTask|noVbs|confirm|scheduler|ignHash|ignVer)"
		If ($m = $(Select-String -CaseSensitive -Pattern $p -AllMatches -InputObject $a)) {
			Invoke-Expression ('{0}="{1}"' -f ($m -Replace "^-", "$"), 1);
			$Args = ($Args) | Where-Object { $_ -ne $m }
		}
	}
	If (($Args.length % 2) -eq 0) {
		$i = 0; While ($Args -Is [Object[]] -And $i -lt $Args.length) {
		<# $i = 0; While ($i -lt $Args.length) { #>
			If (($Args[$i] -Match "^-") -And ($Args[($i+1)] -Match "^[\w\.]")) {
				Invoke-Expression ('{0}="{1}"' -f ($Args[$i] -Replace "^-", "$"), ($Args[++$i]|Out-String).Trim());
			}
		$i++
		}
	} Else { Write-Host -ForeGroundColor Red "ERROR: Invalid options specfied. Try `"$scriptCmd -h`" for help, exiting...`r`n"; Exit 1 }
}

<# DETECT WINDOWS VERSION #>
$osVer = (([System.Environment]::OSVersion).Version)
$osType = (Get-WmiObject Win32_OperatingSystem).ProductType
<# TEST: $osVer = @{ Major = 6; Minor = 1; }; $osType = 3 #>
$osFound = 0; $windowsVersions.GetEnumerator() | ForEach-Object {
	If ( ($(($osVer).Major) -eq $($_.Value[0])) -And ($(($osVer).Minor) -eq $($_.Value[1])) -And ($($osType) -eq $($_.Value[2])) ) {
		$osFound = 1
		$osFullName = ("`"{0}`" ({1}.{2}, {3})" -f $_.Name, ($osVer).Major, ($osVer).Minor, $osTypeList.[int]$($osType))
		$tsModeFound = $_.Value[3]
	}
}
If ($osFound -ne 1) {
	$osFullName = "Unknown Windows Version"
}
If (-Not ($tsMode -Match '^[1-3]$')) {
 	If ($osFound -eq 1) {
		$tsMode = $tsModeFound
	} Else {
		$tsMode = 3
	}
}
Write-Host "OS Detected: $osFullName`r`nTask Scheduler Mode: ${tsMode}, $($tsList.[int]$tsMode)`r`n"

<# LIST VERSION #>
If ($getVer -eq 1) {
	Write-Host -NoNewLine "Currently installed Chromium version: "
	Write-Host $(Get-ItemProperty -ErrorAction SilentlyContinue -WarningAction SilentlyContinue HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Chromium).Version
	Exit 0
}

<# LIST EDITOR ITEMS #>
If ($list -eq 1) {
	$items.GetEnumerator() | Where-Object Value | Format-Table @{l='editor:';e={$_.Name}}, @{l='website, repository, file:';e={$_.Value}} -AutoSize
	Exit 0
}

<# CHECK VARIABLES #>
$m = 0; $items.GetEnumerator() | ForEach-Object {
	If ($_.Name -ceq $editor) {	$m = 1; $website = $items.($editor)[0]; $fileSrc = $items.($editor)[1]; $getFile = $items.($editor)[2] }
}
If ($m -eq 0) {	Write-Host -ForeGroundColor Red "ERROR: Settings incorrect - check editor `"$editor`" (CasE Sensive), exiting..."; Exit 1 }
If (-Not ($channel -cMatch "^(stable|dev)$")) { Write-Host -ForeGroundColor Red "ERROR: Invalid channel `"$channel`" (CasE Sensive), exiting..."; Exit 1 }
If (-Not ($autoUpd -Match "^(0|1)$")) { Write-Host -ForeGroundColor Red "ERROR: Invalid autoUpd setting `"$autoUpd`" - must be 0 or 1, exiting..."; Exit 1 }

<# SCHEDULED TASKS #>

<# VBS WRAPPER #>
$vbsContent = @"
'
' Wrapper for chrupd.cmd to hide window when using Task Scheduler
'
Dim WinScriptHost
For i = 0 to (WScript.Arguments.Count - 1)
	Args = Args & " " & WScript.Arguments(i)
Next
Set WinScriptHost = CreateObject("WScript.Shell")
WinScriptHost.Run Chr(34) & "${scriptDir}$scriptCmd" & Chr(34) & " " & Args, 0
Set WinScriptHost = Nothing
"@
<# SET VARIABLES AND MSGS #>
$confirmParam = $true
If ( $(Try { -Not (Test-Path variable:local:tsMode) -Or ([string]::IsNullOrWhiteSpace($tsMode)) } Catch { $False }) ) {
	$tsMode = 1
}
<# $taskArgs = "-scheduler -editor $editor -channel $channel -autoUpd $autoUpd" #>
$vbsWrapper = $scriptDir + "\chrupd.vbs"
$taskArgs = "-scheduler -editor $editor -channel $channel"
If ($noVbs -eq 0) {
	$taskCmd = "$vbsWrapper"
} Else {
	$taskCmd = 'powershell.exe'
	$taskArgs = "-ExecutionPolicy ByPass -NoLogo -NoProfile -WindowStyle Hidden $scriptCmd $taskArgs"
}
$taskDescr = "Download and install latest Chromium version"
$createMsg = "Creating Daily Task `"$scriptName`" in Task Scheduler..."
$crfailMsg = "Creating Scheduled Task failed."
$swrongMsg = "Something went wrong..."
$existsMsg = "Scheduled Task already exists."
$nfoundMsg = "Scheduled Task not found."
$removeMsg = "Removing Daily Task `"${scriptName}`" from Task Scheduler..."
$rmfailMsg = "Could not remove Task: ${scriptName}."
$notaskMsg = "Scheduled Task already removed."
$manualMsg = "Run `"${scriptCmd} -manTask`" for manual instructions"
$exportMsg = "Run `"${scriptCmd} -xmlTask`" to export a Task XML File"
$xmlContent = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>${taskDescr}</Description>
    <URI>\${scriptName}</URI>
  </RegistrationInfo>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
    </Principal>
  </Principals>
  <Settings>
    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <IdleSettings>
      <Duration>PT10M</Duration>
      <WaitTimeout>PT1H</WaitTimeout>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
  </Settings>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>2018-10-13T17:00:00+02:00</StartBoundary>
      <RandomDelay>PT1H</RandomDelay>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
  </Triggers>
  <Actions Context="Author">
    <Exec>
      <Command>${taskCmd}</Command>
      <Arguments>${taskArgs}</Arguments>
      <WorkingDirectory>${scriptDir}</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@
<# CREATE SCHEDULED TASK #>
If ($crTask -eq 1) {
  If ( $(Try { -Not (&Test-Path $vbsWrapper) } Catch { $False }) ) {
  	Write-Host "VBS Wrapper ($vbsWrapper) missing, creating...`r`n"
  	Set-Content $vbsWrapper -ErrorAction Stop -WarningAction Stop -Value $vbsContent
	  If ( $(Try { -Not (&Test-Path $vbsWrapper) } Catch { $False }) ) {
			Write-Host "Could not create VBS Wrapper, try again or use `"-noVbs`" to skip"
			Exit 1
		}
  }
  Switch ($tsMode) {
	<# NORMAL MODE #>
	1 {
		$action = New-ScheduledTaskAction -Execute $taskCmd -Argument "$taskArgs" -WorkingDirectory "$scriptDir"
		$trigger = New-ScheduledTaskTrigger -RandomDelay (New-TimeSpan -Hour 1) -Daily -At 17:00
		If (-Not (&Get-ScheduledTask -ErrorAction SilentlyContinue -TaskName "$scriptName")) {
			Write-Host $createMsg
			Try { (Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "$scriptName" -Description "$taskDescr") | Out-Null }
				Catch { Write-Host "$swrongMsg`r`nError: `"$($_.Exception.Message)`"" }
		} Else {
			Write-Host $existsMsg
		}
		If (&Get-ScheduledTask -ErrorAction SilentlyContinue -TaskName "$scriptName" -OutVariable task) {
			If ( $(Try { (Test-Path variable:local:task) -And (-Not [string]::IsNullOrWhiteSpace($task)) } Catch { $False }) ) {
			Write-Host ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}`r`n" -f ($task).TaskPath, ($task).TaskName, ($task).Description, ($task).State)
			} Else {
				Write-Host "$crfailMsg"
			}
		}	Else {
			Write-Host ("{0}`r`n`r`n  {1}`r`n  {2}`r`n" -f $crfailMsg, $manualMsg, $exportMsg)
		}
	}
	<# LEGACY MODE #>
	2 {
		$taskService = New-Object -ComObject("Schedule.Service")
		$taskService.Connect()
		$taskFolder = $taskService.GetFolder("\")
		If (-Not $(Try { $taskFolder.GetTask("$scriptName") } Catch { $False }) ) {
			Write-Host $createMsg
			$taskDef = $taskService.NewTask(0) 
			$taskDef.RegistrationInfo.Description = "$TaskDescr"
			$taskDef.Settings.Enabled = $true
			$taskDef.Settings.AllowDemandStart = $true

			$trigCollection = $taskDef.Triggers
			$trigger = $trigCollection.Create(2)

			$trigger.StartBoundary = ((Get-Date).toString("yyyy-MM-dd'T'17:00:00"))
			$trigger.RandomDelay = "PT1H"
			$trigger.DaysInterval = 1
			$trigger.Enabled = $true

			$execAction = $taskDef.Actions.Create(0)
			$execAction.Path = "$taskCmd"
			$execAction.Arguments = "$taskArgs"
			$execAction.WorkingDirectory = "$scriptDir"
			Try { $x = $taskFolder.RegisterTaskDefinition("$scriptName", $taskDef, 6, "", "", 3, "") }
			Catch { Write-Host "$swrongMsg Error: `"$($_.Exception.Message)`"" }
			If ( $(Try { -Not (Test-Path variable:local:x) -Or ( [string]::IsNullOrWhiteSpace($x)) } Catch { $False }) ) {
				Write-Host ("{0}`r`n`r`n  {1}`r`n  {2}`r`n" -f $crfailMsg, $manualMsg, $exportMsg)
			}
		} Else {
			Write-Host $existsMsg
		}
		If ( $(Try { $taskFolder.GetTask("$scriptName") } Catch { $False }) ) {
			$task = $taskFolder.GetTask("$scriptName")
			Write-Host ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}.`r`n" -f $($task.Path), "", $($task.Definition.RegistrationInfo.Description), $($task.State))
		}
	}
	<# CMD MODE #>
	3 {
		Write-Host "$createMsg`r`n"
		Write-Host "Creating Task XML File..."
		Set-Content "$env:TEMP\chrupd.xml" -Value $xmlContent
		$delay = (Get-Random -minimum 0 -maximum 59).ToString("00")
		<# $a = "/Create /SC DAILY /ST 17:${delay} /TN \\`"$scriptName`" /TR `"'$vbsWrapper' $taskArgs`"" #>
		$a = "/Create /TN \\`"$scriptName`" /XML `"$env:TEMP\chrupd.xml`""
		If ($confirm -eq 1) { $a = "$a /F" }
		$p = Start-Process -FilePath "$env:SystemRoot\system32\schtasks.exe" -ArgumentList $a -Wait -NoNewWindow -PassThru
		$handle = $p.Handle
		$p.WaitForExit()
		If ($p.ExitCode -eq 0) {
			Write-Host
		} Else {
			Write-Host ("`r`n{0}`r`n`r`n  {1}`r`n  {2}`r`n" -f $crfailMsg, $manualMsg, $exportMsg)
		}
		Try { Remove-Item -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Force "$env:TEMP\chrupd.xml" } Catch { $False }
	}
}
Exit 0
<# REMOVE SCHEDULED TASK #>
} ElseIf ($rmTask -eq 1) {
	Switch ($tsMode) {
		<# NORMAL MODE #>
  		1 {
			If ($confirm -eq 1) {	$confirmParam = $false }
			If (&Get-ScheduledTask -ErrorAction SilentlyContinue -TaskName "$scriptName") {
				Write-Host "$removeMsg`r`n"
				Try { UnRegister-ScheduledTask -confirm:${confirmParam} -TaskName "$scriptName" } Catch { Write-Host "${wrongMsg}... $($_.Exception.Message)" }
			} Else {
				Write-Host "$notaskMsg`r`n"
			}
			If (&Get-ScheduledTask -ErrorAction SilentlyContinue -TaskName "$scriptName" -OutVariable task) {
				If ( $(Try { (Test-Path variable:local:task) -And (-Not [string]::IsNullOrWhiteSpace($task)) } Catch { $False }) ) {
					Write-Host ("Could not remove Task: `"{0}{1}`", Description: `"{2}`", State: {3}`r`n" -f ($task).TaskPath, ($task).TaskName, ($task).Description, ($task).State)
					Write-Host ("{0}`r`n`r`n{1}`r`n" -f $rmfailMsg, $manualMsg)
				}
			}
		}
		<# LEGACY MODE #>
		2 {
			$taskService = New-Object -ComObject("Schedule.Service")
			$taskService.Connect()
			$taskFolder = $taskService.GetFolder("\")
			If ( $(Try { $taskFolder.GetTask("$scriptName") } Catch { $False }) ) {
				Write-Host "$removeMsg`r`n"
				Try { $taskFolder.DeleteTask("$scriptName", 0) } Catch { Write-Host "${wrongMsg}... $($_.Exception.Message)" }
    		} Else {
    			Write-Host "$notaskMsg`r`n"
    		}
			If ( $(Try { $taskFolder.GetTask("$scriptName") } Catch { $False }) ) {
				$task = $taskFolder.GetTask("$scriptName")
  				Write-Host ("Could not remove Task: `"{0}{1}`", Description: `"{2}`", State: {3}`r`n" -f "", ($task).TaskName, ($task).Description, ($task).State)
   				Write-Host ("{0}`r`n`r`n{1}`r`n" -f $rmfailMsg, $manualMsg)
			}
		}
		<# COMMAND MODE #>
		3 {
			Write-Host "$removeMsg`r`n"
			$a = "/Delete /TN \\`"$scriptName`""
			$p = Start-Process -FilePath "$env:SystemRoot\system32\schtasks.exe" -ArgumentList $a -Wait -NoNewWindow -PassThru
			$handle = $p.Handle
			$p.WaitForExit()
			If ($p.ExitCode -eq 0) {
				Write-Host
			} Else {
				Write-Host ("{0}`r`n`r`n{1}`r`n" -f $rmfailMsg, $manualMsg)
			}
		}
	}
 	Exit 0
<# SHOW SCHEDULED TASK #>
} ElseIf ($shTask -eq 1) {

	Switch ($tsMode) {
		<# NORMAL MODE #>
  		1 {
			If (&Get-ScheduledTask -ErrorAction SilentlyContinue -TaskName "$scriptName" -OutVariable task) {
				If ( $(Try { (Test-Path variable:local:task) -And (-Not [string]::IsNullOrWhiteSpace($task)) } Catch { $False }) ) {
					$taskinfo = (&Get-ScheduledTaskInfo -TaskName "$scriptName")
					Write-Host ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}." -f ($task).TaskPath, ($task).TaskName, ($task).Description, ($task).State)
					Write-Host ("Actions: WorkingDirectory: `"{0}`", Execute: `"{1}`", Arguments: `"{2}`"" -f ($task).actions.WorkingDirectory, ($task).actions.Execute, ($task).actions.Arguments)
					Write-Host ("TaskInfo: LastRunTime: `"{0}`", NextRunTime: `"{1}`", NumberOfMissedRuns: {2}`r`n" -f ($taskinfo).LastRunTime, ($taskinfo).NextRunTime, ($taskinfo).NumberOfMissedRuns)
				}
			} Else {
				Write-Host "$nfoundMsg`r`n"
			}
  		}
		<# LEGACY MODE #>
		2 {
			$taskService = New-Object -ComObject("Schedule.Service")
			$taskService.Connect()
			$taskFolder = $taskService.GetFolder("\")
			If ( $(Try { $taskFolder.GetTask("$scriptName") } Catch { $False }) ) {
				$task = $taskFolder.GetTask("$scriptName")
				Write-Host ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}." -f $($task.Path), "", $($task.Definition.RegistrationInfo.Description), $($task.State))
				Write-Host ("Actions: WorkingDirectory: `"{0}`", Execute: `"{1}`", Arguments: `"{2}`"" -f $($($task.Definition.Actions).WorkingDirectory), $($($task.Definition.Actions).Path), $($($task.Definition.Actions).Arguments))
				Write-Host ("TaskInfo: LastRunTime: `"{0}`", NextRunTime: `"{1}`", NumberOfMissedRuns: {2}`r`n" -f $($task.LastRunTime), $($task.NextRunTime), $($task.NumberOfMissedRuns))
	    	} Else {
    			Write-Host "$nfoundMsg`r`n"
    		}
		}
		<# CMD MODE #>
		3 {
			$a = "/Query /TN \\`"${scriptName}`" /XML" 
			# $p = Start-Process -FilePath "$env:SystemRoot\system32\schtasks.exe" -ArgumentList $a -Wait -NoNewWindow -PassThru
			# $handle = $p.Handle	
			# $p.WaitForExit()
			$pinfo = New-Object System.Diagnostics.ProcessStartInfo
			$pinfo.FileName = "$env:SystemRoot\system32\schtasks.exe"
			$pinfo.RedirectStandardError = $true
			$pinfo.RedirectStandardOutput = $true
			$pinfo.UseShellExecute = $false
			$pinfo.Arguments = "$a"
			$p = New-Object System.Diagnostics.Process
			$p.StartInfo = $pinfo
			$p.Start() | Out-Null
			$p.WaitForExit()
			[xml]$stdout = $p.StandardOutput.ReadToEnd()
			$stderr = $p.StandardError.ReadToEnd()
			If ($p.ExitCode -eq 0) {
				$stOut = (&$env:SystemRoot\system32\schtasks.exe /Query /TN `"$scriptName`" /FO LIST /V)
				$State = $(($stOut | Select-String -Pattern "^Status") -Replace '.*: +(.*)$', '$1')
				$LastRunTime = $(($stOut | Select-String -Pattern "^Last Run Time") -Replace '.*: +(.*)$', '$1')
				$NextRunTime = $(($stOut | Select-String -Pattern "^Next Run Time") -Replace '.*: +(.*)$', '$1')
				Write-Host ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}." -f $($stdout.Task.RegistrationInfo.URI), "", $($stdout.Task.RegistrationInfo.Description), $State)
				Write-Host ("Actions: WorkingDirectory: `"{0}`", Execute: `"{1}`", Arguments: `"{2}`"" -f $($stdout.Task.Actions.Exec.WorkingDirectory), $($stdout.Task.Actions.Exec.Command), $($stdout.Task.Actions.Exec.Arguments))
				Write-Host ("TaskInfo: LastRunTime: `"{0}`", NextRunTime: `"{1}`", NumberOfMissedRuns: {2}`r`n" -f $LastRunTime, $NextRunTime, "?")
			} Else {
	    		Write-Host "$nfoundMsg`r`nError: $stderr"
			}
		}
	}
 	Exit 0
} ElseIf ($manTask -eq 1) {
	Write-Host "Check settings and retry, use a different taskMode (see help) or try"
	Write-Host "manually by going to: `"Start > Task Scheduler`" or `"Run taskschd.msc`".`r`n"
	Write-Host "These settings can be used when creating a New Task :`r`n"
	Write-Host ("  Name: `"{0}`"`r`n    Description `"{1}`"`r`n    Trigger: Daily 17:00 (1H random delay)`r`n    Action: `"{2}`"`r`n    Arguments: `"{3}`"`r`n    WorkDir: `"{4}`"`r`n" `
				-f $scriptName, $taskDescr, $taskCmd, $taskArgs, $scriptDir)
	Exit 0
} ElseIf ($xmlTask -eq 1) {
	Set-Content "$env:TEMP\chrupd.xml" -Value $xmlContent
  If ( $(Try { (&Test-Path "$env:TEMP\chrupd.xml") } Catch { $False }) ) {
  	Write-Host "Exported Task XML File to: `"$env:TEMP\chrupd.xml`""
		Write-Host "File can be imported in Task Scheduler or `"schtasks.exe`".`r`n"
	} Else {
		Write-Host "Could not export XML"
	}
	Exit 0
}

<# VERIFY LOGFILE AND LOG FUNC #>
If ($log -eq 1) {
	If ( $(Try { (Test-Path variable:local:logFile) -And (-Not [string]::IsNullOrWhiteSpace($logFile)) } Catch { $False }) ) {
		Write-Host "Logging to: `"$logFile`"`r`n"
	} Else {
		$log = 0
		Write-Host "Unable to open logfile, output to console only`r`n"
	}
}
Function Write-Log($msg) {
	If ($log -eq 1) { Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " $msg") }
}

If ($debug -eq 1) {
	'_DEBUG_OPTIONS_', 'fakeVer', 'log', 'ignVer', 'ignHash',
	'_STANDARD_OPTIONS_', 'editor', 'channel', 'getFile', 'autoUpd', 'force', 'getVer', 'list', 'website', 'fileSrc', 'getFile',
	'_SCHEDULER_OPTIONS_', 'crTask', 'rmTask', 'shTask', 'xmlTask', 'manTask', 'noVbs', 'confirm', 'scheduler' | ForEach-Object { Write-Host "DEBUG: ${_}:" $(Invoke-Expression `$$_) }
}

Write-Log "Start (pid:$pid name:$($(Get-PSHostProcessInfo | Where-Object ProcessId -eq $pid).ProcessName) scheduler:$scheduler)"

<# VERIFY CURRENT VERSION #>
$curVersion = (Get-ItemProperty -ErrorAction SilentlyContinue -WarningAction SilentlyContinue HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Chromium).Version
If ($force -eq 1) {
	$vMsg = "Forcing update, ignoring currently installed Chromium version `"$curVersion`""
	Write-Host "$vMsg" "`r`n";	Write-Log "$vMsg"
	$curVersion = "00.0.0000.000"
} ElseIf ($fakeVer -eq 1) {
	Write-Host "DEBUG: Changing real current Chromium version `"$curVersion`" to fake value"
	$curVersion = "6.6.6.0-fake"
} Else {
	If ( $(Try { (Test-Path variable:local:curVersion) -And (-Not [string]::IsNullOrWhiteSpace($curVersion)) } Catch { $False }) ) {
		$vMsg = "Currently installed Chromium version: `"$curVersion`""
		Write-Host "$vMsg" "`r`n"; Write-Log "$vMsg"
	} Else {
		$vMsg = "Could not find Chromium, the downloaded installer will install it..."
		Write-Host -ForeGroundColor Yellow "$vMsg"; Write-Log "$vMsg"
		$curVersion = "00.0.0000.000"
	}
}

$cMsg = "Checking: `"$checkSite`", Editor: `"$editor`", Channel: `"$channel`""
Write-Host "Using the folowing settings:`r`n$cMsg`r`n"; Write-Log "$cMsg"

<# MAIN OUTER WHILE LOOP: XML #>
$xml = [xml](Invoke-WebRequest -UseBasicParsing -TimeoutSec 300 -Uri $rssFeed); $i = 0; While ($xml.rss.channel.item[$i]) {
	$editorMatch = 0; $archMatch = 0; $chanMatch = 0; $urlMatch = 0; $hashMatch = 0
	If ($debug -eq 1) {
		Write-Host "DEBUG: $i xml title: $($xml.rss.channel.item[$i].title)"
		Write-Host "DEBUG: $i xml link: $($xml.rss.channel.item[$i].link)"
		<# Write-Host "DEBUG: $i xml description: $($xml.rss.channel.item[$i].description."#cdata-section")" #>
		<# MATCHES: If ($xml.rss.channel.item[$i].title -Match ".*?(Nik)") {$Matches[1]; $editorMatch = 1} #>
		<# MATCHES: If ($debug) {Write-Host "DEBUG: Matches[0], [1]:"; % {$Matches[0]}; % {$Matches[1]}} #>
	}
	<# INNER WHILE LOOP: HTML #>
	$xml.rss.channel.item[$i].description."#cdata-section" | ForEach-Object {
		<# If ($debug) {Write-Host "DEBUG: HTML `$_:`r`n" $_} #>
		If ($_ -Match '(?i)' + $channel + '.*?(Editor: <a href="' + $website + '/">' + $editor + '</a>).*(?i)' + $channel) { $editorMatch = 1 }
		If ($_ -Match '(?i)' + $channel + '.*?(Architecture: 64-bit).*(?i)' + $channel) { $archMatch = 1 }
		If ($_ -Match '(?i)' + $channel + '.*?(Channel: ' + $channel + ')') { $chanMatch = 1 }
		$version = [regex]::Replace($_, '.*(?i)' + $channel + '.*?Version: ([\d.]+).*', '$1')
		$revision = [regex]::Replace($_, '.*(?i)' + $channel + '.*?Revision: (?:<[^>]+>)?(\d{6})<[^>]+>.*', '$1')
		$date = [regex]::Replace($_, '.*(?i)' + $channel + '.*?Date: <abbr title="Date format: YYYY-MM-DD">([\d-]{10})</abbr>.*', '$1')
		$url = [regex]::Replace($_, '.*?(?i)' + $channel + '.*?Download from.*?repository: .*?<li><a href="(' + $fileSrc + '(?:v' + $version + '-r)?' + $revision + '(?:-win64)?/' + $getFile + ')".*', '$1')
		If ($editor -Match "ThumbApps") {
			If ($($xml.rss.channel.item[$i].title) -Match "ThumbApps") {
				$getFile = "${getFile}${version}_Dev_32_64_bit.paf.exe"
				$revision = "thumbapps"
				$ignHash = 1
				$url = [regex]::Replace($_, '.*?(?i)' + $channel + '.*?Download from.*?repository: .*?<li><a href="(' + $fileSrc + $getFile + ')".*', '$1')
				$hMsg = "There is no hash provided for this installer"
				Write-Host "$hMsg"; Write-Log "$hMsg"
			}
		}
		If ($ignVer -eq 1) {
			$url = [regex]::Replace($_, '.*?(?i)' + $channel + '.*?Download from.*?repository: .*?<li><a href="(' + $fileSrc + '(?:v[\d.]+-r)?\d{6}(?:-win64)?/' + $getFile + ')".*', '$1')
			$revision = '\d{6}'
			$vMsg = "Ignoring version mismatch between feed and filename"
			Write-Host -NoNewLine -ForeGroundColor Yellow "`r`n(!) $vMsg"; Write-Log "$vMsg"
		}
		If ($debug -eq 1) {
			 If ($($xml.rss.channel.item[$i].title) -Match $editor) { Write-Host ("{0}`r`n{1}`r`n{0}" -f ("-"*80), "DEBUG: TITLE MATCHES EDITOR") }
			'editor', 'architecture', 'version', 'channel', 'revision', 'date', 'url' | ForEach-Object { Write-Host "DEBUG: $i cdata ${_}:" $(Invoke-Expression `$$_) }
		}
		If ($url -Match ('^https://.*' + '(' + $version + ')?.*' + $revision + '.*' + $getFile + '$') ) {
		 	$urlMatch = 1
			$hashFeed = [regex]::Replace($_, '.*?(?i)' + $channel + '.*?<a href="' + $url + '">' + $getFile + '</a> - (?:(sha1|md5): ([0-9a-f]{32}|[0-9a-f]{40}))</li>.*', '$1 $2')
			$hashAlgo, $hash = $hashFeed.ToUpper().Split(' ')
			If ($ignHash -eq 0) {
				If (($hashAlgo -Match "SHA1|MD5") -And ($hash -Match "[0-9a-f]{32}|[0-9a-f]{40}")) {
					$hashMatch = 1
				} Else {
					$hMsg = "ERROR: No valid hash for installer found, exiting..."
					Write-Host -ForeGroundColor Red "$hMsg"; Write-Log "$hMsg"
					Exit 0
				}
				If ($debug -eq 1) { Write-Host "DEBUG: $i cdata hash: $hash`r`n" }
				Break
			} Else {
				$hMsg = "Ignoring hash - can not verify installer checksum"
				Write-Host -ForeGroundColor Yellow "`r`n(!) ${hMsg}. Press any key to abort or `"c`" to continue...";	Write-Log "$hMsg"
				$host.UI.RawUI.FlushInputBuffer()
				$startTime = Get-Date; $waitTime = New-TimeSpan -Seconds 30
				While ((-Not $host.ui.RawUI.KeyAvailable) -And ($curTime -lt ($startTime + $waitTime))) {
					$curTime = Get-Date; $RemainTime = (($startTime - $curTime) + $waitTime).Seconds
					Write-Host -ForeGroundColor Yellow -NoNewLine "`r    Waiting $($waitTime.TotalSeconds) seconds before continuing, ${remainTime}s left "
				}
				Write-Host "`r`n"
				If ($host.ui.RawUI.KeyAvailable) {
					$x = $host.ui.RawUI.ReadKey("IncludeKeyDown, NoEcho")
					If ($x.VirtualKeyCode -ne "67") { Write-Host "Aborting..."; Write-Log "Aborting..."; Exit 1 }
				}
				$hashFeed = ""; $hash = ""; $hashAlgo = "SHA1"; $hashMatch = 1
				Break
			}
		}
	}
$i++; If ($debug -eq 1) { Write-Host }
}

If ($debug -eq 1) { 'editorMatch', 'archMatch', 'chanMatch', 'urlMatch', 'hashMatch' | ForEach-Object { Write-Host "DEBUG: ${_}:" $(Invoke-Expression `$$_) }; Write-Host }

<# DOWNLOAD LATEST AND CHECK VERSION #>
$saveAs = "$env:TEMP\$getFile"
If (($editorMatch -eq 1) -And ($archMatch -eq 1) -And ($chanMatch -eq 1) -And ($urlMatch -eq 1) -And ($hashMatch -eq 1)) {
	If (($url) -And ($url -NotMatch ".*$curVersion.*")) {
	$ago = ((Get-Date) - ([DateTime]::ParseExact($date,'yyyy-MM-dd', $null)))
	If ($ago.Days -lt 1) { $agoTxt = ($ago.Hours, "hours") } Else { $agoTxt = ($ago.Days, "days")	}
	Write-Host "New Chromium version `"$version`" from $date is available ($agoTxt ago)"; Write-Log "New Chromium version `"$version`" from $date is available ($agoTxt ago)"
		If ($debug -eq 1) {
			If (&Test-Path "$saveAs") { Write-Host "DEBUG: Would have deleted $saveAs" }
			Write-Host "DEBUG: Would have downloaded `"$url`" to `"$saveAs`""
			Write-Host "DEBUG: (!) Make sure `"$saveAs`" ALREADY EXISTS to debug further"
		} Else {
			If (&Test-Path "$saveAs") { Remove-Item "$saveAs" }
			Write-Host "Downloading `"$url`" to `"$saveAs`""
			[System.Net.ServicePointManager]::SecurityProtocol = @("Tls12","Tls11","Tls")
			$wc = New-Object System.Net.WebClient
			$wc.DownloadFile($url, "$saveAs")
			Write-Log "Downloading: `"$url`" to: `"$saveAs`""
		}
	} Else {
		Write-Host -NoNewLine "["; Write-Host -NoNewLine -ForeGroundColor Green "OK"; Write-Host -NoNewLine "] Latest Chromium version already installed"; Write-Host
		Write-Log "Latest Chromium version already installed"
		Exit 0
	}
} Else {
	$vMsg = "No matching Chromium versions found"
	Write-Host "$vMsg - set correct `"channel`" and `"getFile`", exiting...`r`n";	Write-Log "$vMsg"
	Exit 0
}

If ($ignHash -eq 1) {
	$hash = (Get-FileHash -Algorithm $hashAlgo "$saveAs").Hash
	$hMsg = "Ignored hash set to downloaded installer `"$hash`""
	Write-Host "$hMsg"; Write-Log "$hMsg"
}

<# VERIFY HASH AND INSTALL #>
If ((Get-FileHash -Algorithm $hashAlgo "$saveAs").Hash -eq $hash) {
	$hMsg = "$hashAlgo Hash matches `"$hash`""; $eMsg = "Executing `"$getFile`""
	Write-Host "${hMsg}`r`n${eMsg}..."; Write-Log "$hMsg"; Write-Log "$eMsg"
	If ($fakeVer -eq 1) {
		$saveAs = "true"
	}
	If ($debug -eq 1) {
		Write-Host "DEBUG: `$p = Start-Process -FilePath `"$saveAs`" -ArgumentList `"--do-not-launch-chrome`" -Wait -NoNewWindow -PassThru"
	} Else {
		$p = (Start-Process -FilePath "$saveAs" -ArgumentList "--do-not-launch-chrome" -Wait -NoNewWindow -PassThru)
	}
	If ($p.ExitCode -eq 0) {
		$rMsg = "New Chromium version will be used on next (re)start"
	 	Write-Host -NoNewLine "["; Write-Host -NoNewLine -ForeGroundColor Green "OK"; Write-Host -NoNewLine "] Done. "; Write-Host -ForeGroundColor Yellow "${rMsg}."
		Write-Log "Done. $rMsg"
	} Else {
		$errorMsg = "ERROR: after executing `"$getFile`""
		Write-Host -ForeGroundColor Red -NoNewLine "$errorMsg"
		Write-Log "$errorMsg"
		If ($p.ExitCode) {
			Write-Host -ForeGroundColor Red ":" $p.ExitCode
			Write-Log ": $p.ExitCode"
		}
	}
	If (&Test-Path $installLog) {
		$ilogMsg = "Logfile: $installLog"
		Write-Host -ForeGroundColor Red -NoNewLine "`r`n$ilogMsg"; Write-Log "$ilogMsg"
	}
} Else {
	$hMsg = "$hashAlgo Hash does NOT match: `"$hash`""
	Write-Host -ForeGroundColor Red "ERROR: $hMsg, exiting..."; Write-Log "$hMsg"
	Exit 1
}
Write-Host
