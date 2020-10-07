<# :
@echo off
SET "PS_BAT_ARGS=\""%~dp0|"\" %*"
ENDLOCAL & powershell.exe -NoLogo -NoProfile -Command "&(Invoke-Command {[ScriptBlock]::Create('$Args = @( &{$Args} %PS_BAT_ARGS%" );'+[String]::Join([char]10,(Get-Content \"%~f0\")))})"
GOTO :EOF
#>

<# ------------------------------------------------------------------------- #>
<# 20201007 MK: Simple Chromium Updater (chrupd.cmd)                         #>
<# ------------------------------------------------------------------------- #>
<# Uses RSS feed from "chromium.woolyss.com" to download and install latest  #>
<# Chromium version, if a newer version is available. Options can be set     #>
<# below or using command line arguments (try "chrupd.cmd -h")               #>
<#  - default is to get the "64bit" "stable" Installer by "Hibbiki"        	 #>
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

$editor = "Hibbiki"
$arch = "64bit"
$channel = "stable"
$log = 1

<# END OF CONFIGURATION ---------------------------------------------------- #>

$Args = $Args -Replace '\|', ''
#$autoUpd = 0
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
$woolyss = "chromium.woolyss.com"

$debug = $fakeVer = $force = $ignVer = $script:ignHash = 0
$tsMode = $crTask = $rmTask = $shTask = $xmlTask = $manTask = $noVbs = $confirm = 0
$scheduler = $list = $proxy = 0

<# Editors: items[$editor] = @{ url, format, repositoy, filemask } #>
$items = @{
	"Chromium" =	@{url="https://www.chromium.org"; 				fmt="XML"; 	repo="https://storage.googleapis.com/chromium-browser-snapshots/Win_x64/";		fmask="mini_installer.exe"};
	"Hibbiki" = 	@{url="https://$woolyss";						fmt="XML";	repo="https://github.com/Hibbiki/chromium-win64/releases/download/";			fmask="mini_installer.sync.exe"};
	"Marmaduke" = 	@{url="https://$woolyss";						fmt="XML";	repo="https://github.com/macchrome/winchrome/releases/download/";				fmask="mini_installer.exe"};
	"Ungoogled" = 	@{url="https://$woolyss";						fmt="XML";	repo="https://github.com/macchrome/winchrome/releases/download/";				fmask="ungoogled-chromium-.*"};
	"RobRich" = 	@{url="https://$woolyss"; 						fmt="XML"; 	repo="https://github.com/RobRich999/Chromium_Clang/releases/download/"; 		fmask="mini_installer.exe"};
	"ThumbApps" = 	@{url="http://www.thumbapps.org"; 				fmt="XML"; 	repo="https://netix.dl.sourceforge.net/project/thumbapps/Internet/Chromium/"; 	fmask="ChromiumPortable_"};
<#	"Nik" =			@{url="https://$woolyss"; 						fmt="XML"; 	repo="https://github.com/henrypp/chromium/releases/download/";					fmask="chromium-sync.exe"}; #>
<#	"macchrome" = 	@{url="https://github.com/macchrome/winchrome"; fmt="JSON"; repo="https://api.github.com/repos/macchrome/winchrome/releases";				fmask="ungoogled-chromium-"}; #>
}

<# Windows Version: @(majorVer, minorVer, osType[1=ws,3=server], tsMode) #>
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

<# CURRENT CHROMIUM VERSION #>
$curVersion = (Get-ItemProperty -ErrorAction SilentlyContinue -WarningAction SilentlyContinue HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Chromium).Version

Write-Host -ForeGroundColor White -NoNewLine "`r`n$scriptName"; Write-Host " ($scriptCmd)"; Write-Host ("-" * 36)"`r`n"

<# SHOW HELP, HANDLE ARGUMENTS #>
If ($Args -iMatch "[-/][h?]") {
	Write-Host "Uses RSS feed from `"$woolyss`" to download and install latest"
	Write-Host "Chromium version, if a newer version is available.", "`r`n"
	Write-Host "USAGE: $scriptCmd -[editor|arch|channel|force|list]"
	Write-Host "`t`t", " -[tsMode|crTask|rmTask|shTask|noVbs|confirm]", "`r`n"
	Write-Host "`t", "-editor  must be set to one of:"
	Write-Host "`t`t"," <Chromium|Hibbiki|Marmaduke|Ungloogled|RobRich|ThumbApps>"
	Write-Host "`t", "-arch    must be set to <64bit|32bit>"
	Write-Host "`t", "-channel must be set to <stable|dev>"
<# Write-Host "`t", "-autoUpd can set to <0|1> to turn off|on auto updating $scriptCmd" #>
	Write-Host "`t", "-proxy   can be set to <uri> to use a http proxy server"
	Write-Host "`t", "-force   always (re)install, even if latest Chromium is installed"
	Write-Host "`t", "-list    show version, editors and rss feeds from $woolyss", "`r`n"
	Write-Host "`t", "-tsMode  can be set to <1|2|3> or `"auto`" if unset, details below"
	Write-Host "`t", "-crTask  to create a daily scheduled task"
	Write-Host "`t", "-rmTask  to remove scheduled task"
	Write-Host "`t", "-shTask  to show scheduled task details"
	Write-Host "`t", "-noVbs   to not use vbs wrapper to hide window when creating task"
	Write-Host "`t", "-confirm to answer Y on prompt about removing scheduled task", "`r`n"
<# Write-Host "`t" "-ignVer  (!) ignore version mismatch between feed and filename" "`r`n" #>
	Write-Host "EXAMPLE: .\$scriptCmd -editor Marmaduke -arch 64bit -channel stable [-crTask]", "`r`n"
	Write-Host "NOTES:   - Options `"editor`" and `"channel`" need an argument (CasE Sensive)"
	Write-Host "`t", "- Option `"tsMode`" task scheduler modes:"
	Write-Host "`t", "    Unset: OS will be auto detected (Default)"
	Write-Host "`t", "    Or set: 1=Normal (Windows8+), 2=Legacy (Win7), 3=Command (WinXP)"
	Write-Host "`t", "- Schedule `"xxTask`" options can also be used without other settings"
	Write-Host "`t", "- Options can be set permanently using variables inside script", "`r`n"
	Exit 0
} Else {
	ForEach ($a in $Args) {
		$p = "[-/](force|fakeVer|list|rss|crTask|rmTask|shTask|xmlTask|manTask|noVbs|confirm|scheduler|ignHash|ignVer)"
		If ($m = $(Select-String -CaseSensitive -Pattern $p -AllMatches -InputObject $a)) {
			Invoke-Expression ('{0}="{1}"' -f ($m -Replace "^-", "$"), 1);
			$Args = ($Args) | Where-Object { $_ -ne $m }
		}
	}
	If (($Args.length % 2) -eq 0) {
		$i = 0; While ($Args -Is [Object[]] -And $i -lt $Args.length) {
		If ((($Args[$i] -Match "^-debug") -And ($Args[($i+1)] -Match "^\d")) -Or (($Args[$i] -Match "^-") -And ($Args[($i+1)] -Match "^[\w\.]"))) {
		<# $i = 0; While ($i -lt $Args.length) { #>
				Invoke-Expression ('{0}="{1}"' -f ($Args[$i] -Replace "^-", "$"), ($Args[++$i]|Out-String).Trim());
			}
		$i++
		}
	} Else { Write-Host -ForeGroundColor Red "ERROR: Invalid options specfied. Try `"$scriptCmd -h`" for help, exiting...`r`n"; Exit 1 }
}

If ($proxy) {
	$PSDefaultParameterValues.Add("Invoke-WebRequest:Proxy", "$proxy")
	$webproxy = New-Object System.Net.WebProxy
	$webproxy.Address = $proxy
}

<# ALIASES #>
If ("$arch" -Match "32bit|32|x86") { $arch = "32-bit" }
If ("$arch" -Match "64bit|64|x64") { $arch = "64-bit" }
If ($editor -eq "The Chromium Authors") { $editor = "Chromium" }
<# If ("$editor" -eq "Marmaduke") { $editor = "macchrome" } #>

<# DETECT WINDOWS VERSION #>
$osVer = (([System.Environment]::OSVersion).Version)
$osType = (Get-WmiObject Win32_OperatingSystem).ProductType
<# TEST #>
If ($debug -eq 3) {
	$osVer = @{ Major = 6; Minor = 1; }; $osType = 3
}

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

<# LIST VERSION, EDITORS, RSS #>
If ($list -eq 1) {
	Write-Host -NoNewLine "Currently installed Chromium version: "
	Write-Host $curVersion
	Write-Host
	Write-Host "Available Editors:"
	#$items.GetEnumerator() | Where-Object Value | Format-Table @{l='editor:';e={$_.Name}}, @{l='website, repository, file:';e={$_.Value}} -AutoSize
	$items.GetEnumerator() | Where-Object Value | `
		Format-Table @{l='Editor';e={$_.Name}}, `
					 @{l='Website';e={$_.Value.url}}, `
					 @{l='Repository';e={$_.Value.repo}}, `
					 <# @{l='Format';e={$_.Value.fmt}}, ` #>
					 @{l='Filemask';e={$_.Value.fmask}} -AutoSize
	Write-Host "Available from Woolyss RSS Feed:"
	$xml = [xml](Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Uri "https://${woolyss}/feed/windows-${arch}") 
	$xml.rss.channel.item | Select-Object @{N='Title'; E='title'}, @{N='Link'; E='link'} | Out-String
	Exit 0
}

<# CHECK VARIABLES #>

<# REPLACED: using hashtable instead
$m = 0; $items.GetEnumerator() | ForEach-Object {
	If ($_.Name -ceq $editor) {
		$website = $items.($editor)[0]
		$format = $items.($editor)[1]
		$fileSrc = $items.($editor)[2]
		$getFile = $items.($editor)[3]
	}
}
If ($m -eq 0) {	Write-Host -ForeGroundColor Red "ERROR: Settings incorrect - check editor `"$editor`" (CasE Sensive), exiting..."; Exit 1 }
If (-Not ($format -cMatch "^(XML|JSON)$")) { Write-Host -ForeGroundColor Red "ERROR: Invalid format `"$format`", exiting..."; Exit 1 }
If (-Not ($channel -cMatch "^(stable|dev)$")) { Write-Host -ForeGroundColor Red "ERROR: Invalid channel `"$channel`" (CasE Sensive), exiting..."; Exit 1 }
If (-Not ($autoUpd -Match "^(0|1)$")) { Write-Host -ForeGroundColor Red "ERROR: Invalid autoUpd setting `"$autoUpd`" - must be 0 or 1, exiting..."; Exit 1 }
#>

If (-Not ($items[$editor])) { Write-Host -ForeGroundColor Red "ERROR: Settings incorrect - check editor `"$editor`" (CasE Sensive), exiting..."; Exit 1 }
If (-Not ($items[$editor].fmt -cMatch "^(XML|JSON)$")) { Write-Host -ForeGroundColor Red "ERROR: Invalid format `"${items[$editor].fmt}`", exiting..."; Exit 1 }
If (-Not ($arch -cMatch "^(32-bit|64-bit)$")) { Write-Host -ForeGroundColor Red "ERROR: Invalid channel `"$arch`" - must be 32-bit or 64-bit), exiting..."; Exit 1 }
If (-Not ($channel -cMatch "^(stable|dev)$")) { Write-Host -ForeGroundColor Red "ERROR: Invalid channel `"$channel`" (CasE Sensive), exiting..."; Exit 1 }
#If (-Not ($autoUpd -Match "^(0|1)$")) { Write-Host -ForeGroundColor Red "ERROR: Invalid autoUpd setting `"$autoUpd`" - must be 0 or 1, exiting..."; Exit 1 }

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
$taskArgs = "-scheduler -editor $editor -arch $arch -channel $channel"
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
			} Else {
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
			If ($confirm -eq 1) {
				$a = "$a /F"
			}
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
			<# $p = Start-Process -FilePath "$env:SystemRoot\system32\schtasks.exe" -ArgumentList $a -Wait -NoNewWindow -PassThru #>
			<# $handle = $p.Handle	#>
			<# $p.WaitForExit() #>
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
	Write-Host "Check settings and retry, use a different Task Scheduler Mode (see help) or try"
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

If ($debug -ge 1) {
	'__DEBUG_OPTIONS', 'fakeVer', 'log', 'proxy', 'ignVer', 'ignHash', 'autoUpd',
	'__STANDARD_OPTIONS', 'editor', 'arch', 'channel', 'force', 'list', 
	'__ITEM_OPTIONS', 'items[$editor].url', 'items[$editor].fmt', 'items[$editor].repo', 'items[$editor].fmask',
	'__SCHEDULER_OPTIONS', 'crTask', 'rmTask', 'shTask', 'xmlTask', 'manTask', 'noVbs', 'confirm', 'scheduler' | ForEach-Object { Write-Host "DEBUG: ${_} =" $(Invoke-Expression `$$_) }
}

Write-Log "Start (pid:$pid name:$($(Get-PSHostProcessInfo | Where-Object ProcessId -eq $pid).ProcessName) scheduler:$scheduler)"

<# VERIFY CURRENT VERSION #>
If (!$curVersion) {
	$curVersion = (Get-ChildItem ${env:LocalAppData}\Chromium\Application -ErrorAction SilentlyContinue -WarningAction SilentlyContinue |
					Where-Object { $_.Name -Match "\d\d.\d.\d{4}\.\d{1,3}" } ).Name | 
					Sort-Object | Select-Object -Last 1
}
If ($force -eq 1) {
	$vMsg = "Forcing update, ignoring currently installed Chromium version `"$curVersion`""
	Write-Host "$vMsg" "`r`n"
	Write-Log "$vMsg"
	$curVersion = "00.0.0000.000"
} ElseIf ($fakeVer -eq 1) {
	Write-Host "DEBUG: Changing real current Chromium version `"$curVersion`" to fake value"
	$curVersion = "6.6.6.0-fake"
} Else {
	If ( $(Try { (Test-Path variable:local:curVersion) -And (-Not [string]::IsNullOrWhiteSpace($curVersion)) } Catch { $False }) ) {
		$vMsg = "Currently installed Chromium version: `"$curVersion`""
		Write-Host "$vMsg" "`r`n"
		Write-Log "$vMsg"
	} Else {
		$vMsg = "Could not find Chromium, initial installation will be done by the downloaded installer..."
		Write-Host -ForeGroundColor Yellow "$vMsg"
		Write-Log "$vMsg"
		$curVersion = "00.0.0000.000"
	}
}

$cMsg = "Checking: `"$woolyss`", Editor: `"$editor`", Architecture: `"$arch`", Channel: `"$channel`""
Write-Host "Using the folowing settings:`r`n$cMsg`r`n"
Write-Log "$cMsg"

Function hashPreCheck ($hashAlgo, $hash) {
	If ($script:ignHash -eq 0) {
		If (($hashAlgo -Match "SHA1|MD5") -And ($hash -Match "[0-9a-f]{32}|[0-9a-f]{40}")) {
			$script:hashMatch = 1
		} Else {
			$hMsg = "ERROR: No valid hash for installer/archive file found, exiting..."
			Write-Host -ForeGroundColor Red "$hMsg"
			Write-Log "$hMsg"
			Exit 0
		}
		If ($debug -ge 1) { Write-Host "DEBUG: i = $i cdata hash = $hash`r`n" }
	} Else {
		$hMsg = "Ignoring hash. Could not verify checksum of installer/archive file."
		Write-Host -ForeGroundColor Yellow "`r`n(!) ${hMsg}`r`n    Press any key to abort or `"c`" to continue...`r`n"
		Write-Log "$hMsg"
		$host.UI.RawUI.FlushInputBuffer()
		$startTime = Get-Date; $waitTime = New-TimeSpan -Seconds 30
		While ((-Not $host.ui.RawUI.KeyAvailable) -And ($curTime -lt ($startTime + $waitTime))) {
			$curTime = Get-Date; $RemainTime = (($startTime - $curTime) + $waitTime).Seconds
			Write-Host -ForeGroundColor Yellow -NoNewLine "`r    Waiting $($waitTime.TotalSeconds) seconds before continuing, ${remainTime}s left "
		}
		Write-Host "`r`n"
		If ($host.ui.RawUI.KeyAvailable) {
			$x = $host.ui.RawUI.ReadKey("IncludeKeyDown, NoEcho")
			If ($x.VirtualKeyCode -ne "67") {
				Write-Host "Aborting..."
				Write-Log "Aborting..."
				Exit 1
			}
		}
		$script:hashMatch = 1
		$script:hash = ""; $script:hashAlgo = "SHA1"

	}
	#Return $hashMatch
}

Function sevenZip ([string]$action, [string]$7zArgs) {
	If (&Test-Path "$env:ProgramFiles\7-Zip\7z.exe") {
		$7z = "$env:ProgramFiles\7-Zip\7z.exe"  
	} Else {
		$sMsg =  "7-Zip (`"7z.exe`") not found"
		Write-Host -ForeGroundColor Red "ERROR: $sMsg, exiting..."
		Write-Log "$ssg"
		Exit 1
	}
	<# Source: http://www.mobzystems.com/code/7-zip-powershell-module/ #>
	If ($action -eq "listdir") {
		[string[]]$result = &$7z l $7zargs
		[bool]$separatorFound = $false
		$result | ForEach-Object {
			If ($_.StartsWith("------------------- ----- ------------ ------------")) {
				If ($separatorFound) {
					# Second separator! We're done
					Return
				}
				$separatorFound = -Not $separatorFound
			} Else {
				If ($separatorFound) {
					[string]$mode = $_.Substring(20, 5)
					[string]$name = $_.Substring(53).TrimEnd()
					If (($mode -Match "^D") -And (-Not $dirName)) {
						If ($debug -ge 1) { Write-Host "DEBUG: sevenZip name = $name" }
						$dirName = $name
						Return
					}
				}
			}
		}
		Return $dirName
	}
	ElseIf ($action -eq "extract") {
		If ($debug -ge 1) {
			Write-Host "DEBUG: `$p = Start-Process -FilePath `"$7z`" -ArgumentList $7zArgs -NoNewWindow -PassThru -Wait"
		}
		$p = Start-Process -FilePath "$7z" -ArgumentList "$7zArgs" -NoNewWindow -PassThru -Wait
		Return $p.ExitCode
	}
}

Function createShortcut ([string]$srcExe, [string]$srcExeArgs, [string]$dstPath) {
	If (&Test-Path $srcExe) {
		If ( $(Try { (Test-Path variable:local:dstPath) -And (&Test-Path $dstPath) -And (-Not [string]::IsNullOrWhiteSpace($dstPath)) } Catch { $False }) ) {
			Try { Remove-Item -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Force "$dstPath" } Catch { $False }
		}
		$WshShell = New-Object -comObject WScript.Shell
		<# $WshShell.SpecialFolders("Desktop") #>
		$Shortcut = $WshShell.CreateShortcut($dstPath)
		$Shortcut.Arguments = $srcExeArgs
		<# $Shortcut.Description #>
		<# $Shortcut.HotKey #>
		<# $Shortcut.IconLocation #>
		<# $Shortcut.RelativePath #>
		$Shortcut.TargetPath = $srcExe
		<# $Shortcut.WindowStyle #>
		<# $Shortcut.WorkingDirectory #>
		$Shortcut.Save()
	} Else {
		$sMsg = "Shortcut target `"$srcExe`" does not exist"
		Write-Host -ForeGroundColor Red "ERROR: $sMsg"
		Write-Log "$sMsg"
		Return $false
	}
	Return $true
}

<# EXTRACT VARIABLES FROM RSS #>
Function parseRss ($rssFeed) {
	<# MAIN OUTER WHILE LOOP: XML #>
	$script:editorMatch = $script:archMatch = $script:chanMatch = $script:urlMatch = $script:hashMatch = $False
	$xml = [xml](Invoke-WebRequest -UseBasicParsing -TimeoutSec 300 -Uri $rssFeed); $i = 0
	While ($xml.rss.channel.item[$i]) {
		If ($debug -ge 1) {
			Write-Host "DEBUG: i = $i xml title = $($xml.rss.channel.item[$i].title)"
			Write-Host "DEBUG: i = $i xml link = $($xml.rss.channel.item[$i].link)"
			If ($debug -ge 2) {
				Write-Host "DEBUG: i = $i xml description = : $($xml.rss.channel.item[$i].description."#cdata-section")" #>
			}
			<# DEBUG MATCHES: call after '-Match' with '&matches' #>
			$matches = {
				If ($xml.rss.channel.item[$i].title -Match ".*?(Marmaduke)") {$Matches[1]; $editorMatch = 1}
				If ($debug -ge 2) {Write-Host "DEBUG: Matches[0], [1] = "; % {$Matches[0]}; % {$Matches[1]}}
			}
		}
		<# INNER WHILE LOOP: HTML #>
		$xml.rss.channel.item[$i].description."#cdata-section" | ForEach-Object {
			<# If ($debug) {Write-Host "DEBUG: HTML `$_ = `r`n" $_} #>
			$script:editorMatch = $_ -Match '(?i)' + $channel + '.*?(Editor: <a href="' + $items[$editor].url + '/">' + $editor + '</a>).*(?i)' + $channel
			$script:archMatch =  $_ -Match '(?i)' + $channel + '.*?(Architecture: ' + $arch + ').*(?i)' + $channel
			$script:chanMatch = $_ -Match '(?i)' + $channel + '.*?(Channel: ' + $channel + ')'
			$script:version = $_ -Replace ".*(?i)$channel.*?Version: ([\d.]+).*", '$1'
			$revision = $_ -Replace ".*(?i)$channel.*?Revision: (?:<[^>]+>)?(\d{3}|\d{6})<[^>]+>.*", '$1'
			$script:date = $_ -Replace ".*(?i)$channel.*?Date: <abbr title=`"Date format: YYYY-MM-DD`">([\d-]{10})</abbr>.*", '$1'
			$script:url = $_ -Replace ".*?(?i)$channel.*?Download from.*?repository:.*?<li><a href=`"($($items[$editor].repo)(?:v$script:version-r)?$revision(?:-win$($arch.replace('-bit','')))?/$($items[$editor].fmask))`".*", '$1'
			<# SET NON-MATCHES TO NULL #>
			ForEach ($var in "script:version", "revision", "script:date", "script:url") {
				If ($(Invoke-Expression `$$var) -eq $_) {
					Invoke-Expression ('{0}="{1}"' -f ($var -Replace "^", "$"), $null);
				}
			}
			<# EDITOR EXCEPTIONS #>
			If (($($xml.rss.channel.item[$i].title) -Match "Ungoogled") -And
				($_ -Match '(?i)' + $channel + '.*?(Editor: <a href="' + $items[$editor].url + '/">' + "Marmaduke" + '</a>).*(?i)' + $channel))
			{ 
				$script:editorMatch = $True
				$items[$editor].fmask = $url -Replace ".*/($($items[$editor].fmask)$version.*\.7z)$", '$1'
			}
			ElseIf ($_ -Match '(?i)' + $channel + '.*?(Editor: <a href="' + $items[$editor].url + '/">' + "ThumbApps" + '</a>).*(?i)' + $channel) { 
				$items[$editor].fmask += "${version}_Dev_32_64_bit.paf.exe"
				$script:editorMatch = $True
				$revision = "thumbapps"
				$script:url = $_ -Replace ".*?(?i)$channel.*?Download from.*?repository: .*?<li><a href=`"($($items[$editor].repo)$($items[$editor].fmask))`".*", '$1'
				$script:ignHash = 1
				$hMsg = "There is no hash provided for this installer"
				Write-Host "$hMsg"
				Write-Log "$hMsg"
			}
			If ($ignVer -eq 1) {
				$revision = '\d{6}'
				$script:url = $_ -Replace ".*?(?i)$channel.*?Download from.*?repository:.*?<li><a href=`"($($items[$editor].repo)(?:v[\d.]+-r)?$revision(?:-win$($arch.replace('-bit','')))?/$($items[$editor].fmask))`".*", '$1'
				$vMsg = "Ignoring version mismatch between RSS feed and filename"
				Write-Host -NoNewLine -ForeGroundColor Yellow "`r`n(!) $vMsg"; Write-Host 
				Write-Log "$vMsg"
			}
			If ($debug -ge 1) {
				If ($($xml.rss.channel.item[$i].title) -Match $editor) {
					Write-Host ("{0}`r`n{1}`r`n{0}" -f ("-"*80), "DEBUG: 'TITLE' -MATCHES 'EDITOR'")
				}
				'editorMatch', 'archMatch', 'chanMatch', 'version', 'channel', 'revision', 'date', 'url' | ForEach-Object {
					Write-Host "DEBUG: i = $i 	${_} = " $(Invoke-Expression `$$_)
				}
			}
			<# CHECK URL, HASH AND BREAK LOOP #>
			If ($script:url -Match ('^https://.*' + '(' + $version + ')?.*' + $revision + '.*' + $items[$editor].fmask + '$') ) {
				$script:urlMatch = 1
				$hashFeed = $_ -Replace ".*?(?i)$channel.*?<a href=`"$url`">$($items[$editor].fmask)</a><br />(?:(sha1|md5): ([0-9a-f]{32}|[0-9a-f]{40}))</li>.*", '$1 $2'
				Write-Host "DEBUG: --> $hashFeed"
				#exit
				$script:hashAlgo, $script:hash = $hashFeed.ToUpper().Split(' ')
				hashPreCheck "$script:hashAlgo" "$script:hash"
				Break
			}
		}
		$i++
		If ($debug -ge 1) { Write-Host }
	}
}
$rMsg = "Repository format `"$items[$editor].fmt`" or URL `"$($items[$editor].repo)`" not recognized"
If ($items[$editor].fmt -eq "XML") {
	parseRss "https://${woolyss}/feed/windows-${arch}"
<# 
} ElseIf ($items[$editor].fmt -eq "JSON") {
	If ("$($items[$editor].repo).*" -Match "^https://api.github.com" ) {
		parseJsonGh $items[$editor].repo
	} Else {
		Write-Host -ForeGroundColor Red "ERROR: $rMsg, exiting..."
		Write-Log "$rMsg"
		Exit 1
	}
#>
} Else {
	Write-Host -ForeGroundColor Red "ERROR: $rMsg, exiting..."
	Write-Log "$rMsg"
	Exit 1
}

If ($debug -ge 1) {
	'editorMatch', 'archMatch', 'chanMatch', 'urlMatch', 'hashMatch' | ForEach-Object {
		Write-Host "DEBUG: ${_}(AFTER) = " $(Invoke-Expression `$$_)
	}
	Write-Host
}

<# DOWNLOAD LATEST AND CHECK VERSION #>
$saveAs = "$env:TEMP\$($items[$editor].fmask)"
If (($editorMatch -eq 1) -And ($archMatch -eq 1) -And ($chanMatch -eq 1) -And ($urlMatch -eq 1) -And ($hashMatch -eq 1)) {
	If (($url) -And ($url -NotMatch ".*$curVersion.*")) {
		$ago = ((Get-Date) - ([DateTime]::ParseExact($date,'yyyy-MM-dd', $null)))
		If ($ago.Days -lt 1) {
			$agoTxt = ($ago.Hours, "hours")
		} Else {
			$agoTxt = ($ago.Days, "days")
		}
		$nMsg = "New Chromium version `"$version`" from $date is available ($agoTxt ago)"
		Write-Host $nMsg
		Write-Log $nMsg
		If ($debug -ge 1) {
			If (&Test-Path "$saveAs") {
				Write-Host "DEBUG: Would have deleted $saveAs"
			}
			Write-Host "DEBUG: Would have downloaded: `"$url`""
			Write-Host "DEBUG:$(" "*15)To path: `"$saveAs`""
			Write-Host -ForeGroundColor Yellow "DEBUG: (!) Make sure `"$saveAs`" ALREADY EXISTS to continue debugging"
		} Else {
			If (&Test-Path "$saveAs") {
				Remove-Item "$saveAs"
			}
			Write-Host "Downloading `"$url`""
			Write-Host "Saving as: `"$saveAs`""
			[System.Net.ServicePointManager]::SecurityProtocol = @("Tls12","Tls11","Tls")
			$wc = New-Object System.Net.WebClient
			If ($proxy) {
				$wc.Proxy = $webproxy
			}
			$wc.DownloadFile($url, "$saveAs")
			Write-Log "Downloading: `"$url`""
			Write-Log "Saving as: `"$saveAs`""
		}
	} Else {
		$lMsg = "Latest Chromium version already installed"
		Write-Host -NoNewLine "["; Write-Host -NoNewLine -ForeGroundColor Green "OK"; Write-Host -NoNewLine "] $lMsg"; Write-Host
		Write-Log "$lMsg"
		Exit 0
	}
} Else {
	$vMsg = "No matching Chromium versions found"
	Write-Host "$vMsg - set correct `"channel`" and `"editor`", exiting...`r`n";	Write-Log "$vMsg"
	Exit 0
}

If ($script:ignHash -eq 1) {
	$script:hash = (Get-FileHash -Algorithm $hashAlgo "$saveAs").Hash
	$hMsg = "Ignoring hash, using hash from downloaded installer: `"$hash`""
	Write-Host "$hMsg"
	Write-Log "$hMsg"
}

<# VERIFY HASH AND INSTALL/EXTRACT #>
If ( $(Try { -Not (Test-Path variable:script:hashAlgo) -Or ([string]::IsNullOrWhiteSpace($script:hashAlgo)) } Catch { $False }) ) {
	$hMsg = "Hash Algorithm is missing"
	Write-Host -ForeGroundColor Red "ERROR: $hMsg, exiting..."
	Write-Log "$hMsg"
	Exit 1
}
If ( $(Try { -Not (Test-Path variable:script:hash) -Or ([string]::IsNullOrWhiteSpace($script:hash)) } Catch { $False }) ) {
	$hMsg = "Hash is missing"
	Write-Host -ForeGroundColor Red "ERROR: $hMsg, exiting..."
	Write-Log "$hMsg"
	Exit 1
}
If ((Get-FileHash -Algorithm $hashAlgo "$saveAs").Hash -eq $hash) {
	$hMsg = "$hashAlgo Hash matches `"$hash`""
	If ($saveAs -Match ".*.exe$") {
		$fileFmt = "exe"; $eMsg = "Executing `"$($items[$editor].fmask)`""
		Write-Host "${hMsg}`r`n${eMsg}..."
		Write-Log "$hMsg"; Write-Log "$eMsg"
	} ElseIf ($saveAs -Match ".*.(7z|zip)$") {
		$fileFmt = "arc"
		$i=0; $extrTo = ""
		ForEach ($extrTo in "$env:LocalAppData\Chromium\Application", "$([Environment]::GetFolderPath('Desktop'))", "$env:USERPROFILE\Desktop", "$env:TEMP") {
			If ($extrTo -ne "") {
				$i++
				Break
			}
		}
		If ($i -gt 0) {
			$eMsg = "Extracting `"$($items[$editor].fmask)`" to `"$extrTo`""
		} Else {
			$xMsg = "Could not find dir to extract to"
			Write-Host -ForeGroundColor Red "ERROR: $xMsg, exiting..."
			Write-Log "$xMsg"
			Exit 1
		}
	}
	#If ($fakeVer -eq 1) { $saveAs += "-FakeVer" }
	$doneMsg = {
		Write-Host -NoNewLine "["; Write-Host -NoNewLine -ForeGroundColor Green "OK"; Write-Host -NoNewLine "] Done. "; Write-Host -ForeGroundColor Yellow "${rMsg}."
		Write-Log "Done. $rMsg"
	}
	If ($fileFmt -eq "exe") {
		$exeArgs = "--do-not-launch-chrome"
		If ($debug -ge 1) {
			Write-Host "DEBUG: `$p = Start-Process -FilePath `"$saveAs`" -ArgumentList $exeArgs -Wait -NoNewWindow -PassThru"
		}
		$p = (Start-Process -FilePath "$saveAs" -ArgumentList $exeArgs -Wait -NoNewWindow -PassThru)
		If ($p.ExitCode -eq 0) {
			$rMsg = "New Chromium version will be used on next (re)start"
			& $doneMsg
		} Else {
			$errorMsg = "ERROR: after executing `"$($items[$editor].fmask)`""
			Write-Host -ForeGroundColor Red -NoNewLine "$errorMsg"
			Write-Log "$errorMsg"
			If ($p.ExitCode) {
				Write-Host -ForeGroundColor Red ":" $p.ExitCode
				Write-Log ": " $p.ExitCode
			}
		}
		If (&Test-Path $installLog) {
			$ilogMsg = "Installer logfile: $installLog"
			Write-Host -ForeGroundColor Red -NoNewLine "`r`n$ilogMsg"
			Write-Log "$ilogMsg"
		}
	} ElseIf ($fileFmt -eq "arc") {
		$retArcDir = &sevenZip "listdir" "$saveAs"
		If ($debug -ge 1) {
			Write-Host "DEBUG: extrTo\retArcdir = ${extrTo}\${retArcdir}"
		}
		If (-Not (&Test-Path "${extrTo}\${retArcdir}")) {
			If ($retArcDir) {
				$retExtract = &sevenZip "extract" "x $saveAs -o${extrTo} -y"
				If ($retExtract -eq 0) {
					$rMsg = "New Chromium version extracted to `"${extrTo}\${retArcdir}`""
					$lnkTarget = "${extrTo}\${retArcdir}\chrome.exe"
					<# $lnkName = "$env:USERPROFILE\Desktop\Chromium $version.lnk" #>
					$lnkName = "$env:USERPROFILE\Desktop\Chromium.lnk"
					If ($debug -ge 1) {
						Write-Host "DEBUG: lnkTarget = `"$lnkTarget`" linkName = `"$lnkName`""
					}
					$retShortcut = &createShortcut "$lnkTarget" "" "$lnkName"
					If (-Not $retShortcut) {
						$eMsg = "Could not create shortcut on Desktop"
						Write-Host -ForeGroundColor Red "ERROR: $eMsg"
						Write-Log "$eMsg"
					} Else {
						$rMsg += " and shortcut created on Desktop"
					}
					& $doneMsg
				} Else {
					$eMsg = "Could not extract `"$saveAs`""
					Write-Host -ForeGroundColor Red "ERROR: $eMsg, exiting..."
					Write-Log "$eMsg"
					Exit 1
				}
			} Else {
				$lMsg = "No directory to extract found inside archive `"$saveAs`""
				Write-Host -ForeGroundColor Red "ERROR: $lMsg, exiting..."
				Write-Log "$lMsg"
				Exit 1
			}
		} Else {
			$eMsg = "Directory `"${extrTo}\${retArcDir}`" already exists"
			Write-Host -ForeGroundColor Red "ERROR: $eMsg, exiting..."
			Write-Log "$eMsg"
			Exit 1
		}
	}
} Else {
	$hMsg = "$hashAlgo Hash does NOT match: `"$hash`""
	Write-Host -ForeGroundColor Red "ERROR: $hMsg, exiting..."
	Write-Log "$hMsg"
	Exit 1
}
Write-Host
