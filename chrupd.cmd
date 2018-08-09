<# :
@echo off
SETLOCAL & SET "PS_BAT_ARGS=%~dp0 %*"
IF DEFINED PS_BAT_ARGS SET "PS_BAT_ARGS=%PS_BAT_ARGS:"="""%"
ENDLOCAL & powershell.exe -NoLogo -NoProfile -Command "&(Invoke-Command {[ScriptBlock]::Create('$Args = @( &{$Args} %PS_BAT_ARGS% );'+[String]::Join([char]10,(Get-Content \"%~f0\")))})"
GOTO :EOF
#>

<# ------------------------------------------------------------------------- #>
<# 20180808 MK: Simple Chromium Updater (chrupd.cmd)                         #>
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
<# - To update chrupd to a newer versions just replace this file.            #>
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

$scriptDir = $Args[0]
If ( $(Try { (Test-Path variable:local:scriptDir) -And (&Test-Path $scriptDir) -And (-Not [string]::IsNullOrWhiteSpace($scriptDir)) } Catch { $False }) ) {
	$rm = ($Args[0]); $Args = ($Args) | Where { $_ -ne $rm }
} Else { 
	$scriptDir = ($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.\'))
}

$logFile = $scriptDir + "\chrupd.log"
$scriptName = "Simple Chromium Updater"; $scriptCmd = "chrupd.cmd"
$installLog = "$env:TEMP\chromium_installer.log"
$checkSite = "chromium.woolyss.com"
$rssFeed = "https://$checkSite/feed/windows-64-bit"

$debug = $fakeVer = $force = $ignVer = $ignHash = 0
$crTask = $rmTask = $shTask = $noVbs = $confirm = 0
$scheduler = $list = 0

$items = @{ 
	"Nik" = @("https://$checkSite", "https://github.com/henrypp/chromium/releases/download/", "chromium-sync.exe");
	"RobRich" = @("https://$checkSite", "https://github.com/RobRich999/Chromium_Clang/releases/download/", "mini_installer.exe");
	"Chromium" =  @("https://www.chromium.org", "https://storage.googleapis.com/chromium-browser-snapshots/Win_x64/", "mini_installer.exe");
	"The Chromium Authors" =  ($items.("Chromium"));
	"ThumbApps" = @("http://www.thumbapps.org", "https://netix.dl.sourceforge.net/project/thumbapps/Internet/Chromium/", "ChromiumPortable_");
}

Write-Host -ForeGroundColor White -NoNewLine "`r`n$scriptName"; Write-Host " ($scriptCmd)"; Write-Host ("-" * 36)"`r`n"

<# HANDLE ARGUMENTS #> 
<# REMOVED: Options related to Nik's nosync build #>
If ($Args -iMatch "[-/]h") {
	Write-Host "Uses RSS feed from `"$checkSite`" to download and install latest"
	Write-Host "Chromium version, if a newer version is available." "`r`n"
	Write-Host "USAGE: $scriptCmd -[editor|channel|force|list]"
	Write-Host "`t`t" " -[crTask|rmTask|shTask|noVbs|confirm]" "`r`n"
	Write-Host "`t" "-editor  can be set to <Nik|RobRich|Chromium|ThumbApps>"
	Write-Host "`t" "-channel can be set to <stable|dev>"
<# Write-Host "`t" "-getFile can be set to [chromium-sync.exe|chromium-nosync.exe]" #>
	Write-Host "`t" "-force   always (re)install, even if latest version installed already"
	Write-Host "`t" "-list    lists editors and urls" "`r`n"
	Write-Host "`t" "-crTask  to create a daily scheduled task"
	Write-Host "`t" "-rmTask  to remove scheduled task"
	Write-Host "`t" "-shTask  to show scheduled task details"
	Write-Host "`t" "-noVbs   to not use vbs wrapper to hide window when creating task"
	Write-Host "`t" "-confirm to answer Y on prompt about removing scheduled task" "`r`n"
<# Write-Host "`t" "-ignVer  (!) ignore version mismatch between feed and filename" "`r`n"
	 Write-Host "EXAMPLE: .\$scriptCmd -editor Nik -channel stable -getFile chromium-nosync.exe"
#>
	Write-Host "EXAMPLE: .\$scriptCmd -editor Nik -channel stable [-crTask]" "`r`n"
	Write-Host "NOTES:   Options `"editor`" and `"channel`" need an argument (CasE Sensive)"
<# Write-Host "`t" "Option `"getFile`" is only used if editor is set to `"Nik`"" #>
	Write-Host "`t" "Schedule `"xxTask`" options can also be used without any other options"
	Write-Host "`t" "Options can be set permanently using variables inside script" "`r`n"
	Exit 0
} Else {
	ForEach ($a in $Args) {
		If ($m = $(Select-String -Pattern "[-/](debug|force|fakeVer|list|crTask|rmTask|shTask|noVbs|confirm|scheduler|ignHash|ignVer)" -AllMatches -InputObject $a)) {
			Invoke-Expression ('{0}="{1}"' -f ($m -Replace "^-", "$"), 1);
			$Args = ($Args) | Where { $_ -ne $m }
		}
	}
	If (($Args.length % 2) -eq 0) {
		$i = 0; While ($Args -Is [Object[]] -And $i -lt $Args.length) {
		#$i = 0; While ($i -lt $Args.length) {	
			If (($Args[$i] -Match "^-") -And ($Args[($i+1)] -Match "^[\w\.]")) {
				Invoke-Expression ('{0}="{1}"' -f ($Args[$i] -Replace "^-", "$"), $Args[++$i].Trim());
			} 
		$i++
		}
	} Else { Write-Host -ForeGroundColor Red "ERROR: Invalid options specfied. Try `"$scriptCmd -h`" for help, exiting...`r`n"; Exit 1 }
}

<# LIST EDITOR ITEMS #>
If ($list -eq 1) {
	$items.GetEnumerator() | where Value | ft @{l='editor:';e={$_.Name}}, @{l='website, repository, file:';e={$_.Value}} -AutoSize
	Exit 0
}

<# CHECK VARIABLES #>
$m = 0; $items.GetEnumerator() | % {
	If ($_.Name -ceq $editor) {	$m = 1; $website = $items.($editor)[0]; $fileSrc = $items.($editor)[1]; $getFile = $items.($editor)[2] }
}
If ($m -eq 0) {	Write-Host -ForeGroundColor Red "ERROR: Settings incorrect - check editor `"$editor`" (CasE Sensive), exiting..."; Exit 1 }
If (-Not ($channel -cMatch "^(stable|dev)$")) { Write-Host -ForeGroundColor Red "ERROR: Invalid channel `"$channel`" (CasE Sensive), exiting..."; Exit 1 }

<# SCHTASK VBS WRAPPER #>
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

<# HANDLE SCHEDULED TASK #>
If ($crTask -eq 1) {
	$vbsWrapper = $scriptDir + "chrupd.vbs"
	If ( $(Try { -Not (&Test-Path $vbsWrapper) } Catch { $False }) ) {
		Write-Host "VBS Wrapper ($vbsWrapper) missing, creating..."
		Add-Content $vbsWrapper -Value $vbsContent
	}
	If ($noVbs -eq 1) {
		$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy ByPass -NoLogo -NoProfile -WindowStyle Hidden $scriptCmd -scheduler -editor $editor -channel $channel" -WorkingDirectory "$scriptDir"
	} Else {
		$action = New-ScheduledTaskAction -Execute $vbsWrapper -Argument "-scheduler -editor $editor -channel $channel" -WorkingDirectory "$scriptDir"
	}
	$trigger = New-ScheduledTaskTrigger -RandomDelay (New-TimeSpan -Hour 1) -Daily -At 17:00
	If (-Not (&Get-ScheduledTask -ErrorAction SilentlyContinue -TaskName "$scriptName")) {
		Write-Host "Creating Daily Task `"$scriptName`" in Task Scheduler..."
		Try { (Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "$scriptName" -Description "Download and install latest Chromium version") } Catch { Write-Host "Something went wrong... $($_.Exception.Message)" }
	} Else {
		Write-Host "Scheduled Task already exists"
	}
	$task = (Get-ScheduledTask -TaskName "$scriptName")
	Write-Host ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}." -f ($task).TaskPath, ($task).TaskName, ($task).Description, ($task).State);	Write-Host
} ElseIf ($rmTask -eq 1) {
	If (&Get-ScheduledTask -ErrorAction SilentlyContinue -TaskName "$scriptName") {
		Write-Host "Removing Daily Task `"$scriptName`" from Task Scheduler..."`r`n""
		If ($rmTask -eq 1) { $confirm = $false } Else { $confirm = $true }
		Try { UnRegister-ScheduledTask -Confirm:$confirm -TaskName "$scriptName" } Catch { Write-Host "Something went wrong... $($_.Exception.Message)" }
	} Else { 
		Write-Host "Scheduled Task already removed`r`n"
	}
	If (&Get-ScheduledTask -ErrorAction SilentlyContinue -TaskName "$scriptName" -OutVariable task) {
		Write-Host ("Could not remove Task: `"{0}{1}`", Description: `"{2}`", State: {3}." -f ($task).TaskPath, ($task).TaskName, ($task).Description, ($task).State)
		Write-Host "Please try removing it manually using `"Start > Task Scheduler`"."; Write-Host
	}
	Exit 0
} ElseIf ($shTask -eq 1) {
	If ($task = (&Get-ScheduledTask -ErrorAction SilentlyContinue -TaskName "$scriptName")) {
		$taskinfo = (&Get-ScheduledTaskInfo -TaskName "$scriptName")
		Write-Host ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}." -f ($task).TaskPath, ($task).TaskName, ($task).Description, ($task).State); Write-Host
		Write-Host ("Actions: WorkingDirectory: `"{0}`", Execute: `"{1}`", Arguments: `"{2}`"" -f ($task).actions.WorkingDirectory, ($task).actions.Execute, ($task).actions.Arguments)
		Write-Host ("TaskInfo: LastRunTime: `"{0}`", NextRunTime: `"{1}`", NumberOfMissedRuns: {2}" -f ($taskinfo).LastRunTime, ($taskinfo).NextRunTime, ($taskinfo).NumberOfMissedRuns); Write-Host
	} Else { 
		Write-Host "Scheduled Task not found"
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
	'_DEBUG_OPTIONS_', 'fakeVer', 'log', 'ignVer', 'ignHash'
	'_STANDARD_OPTIONS_', 'editor', 'channel', 'getFile', 'force', 'list', 'website', 'fileSrc', 'getFile', 
	'_SCHEDULER_OPTIONS_', 'crTask', 'rmTask', 'shTask', 'noVbs', 'confirm', 'scheduler' | % { Write-Host "DEBUG: ${_}:" $(Invoke-Expression `$$_) }
}

Write-Log "Start (pid:$pid name:$($(Get-PSHostProcessInfo|where ProcessId -eq $pid).ProcessName) scheduler:$scheduler)"

<# VERIFY CURRENT VERSION #>
$curVersion = (Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Chromium).Version
If ($force -eq 1) { 
	$vMsg = "Forcing update, ignoring currently installed version `"$curVersion`""
	Write-Host "$vMsg" "`r`n";	Write-Log "$vMsg"
	$curVersion = "00.0.0000.000"
} ElseIf ($fakeVer -eq 1) {
	Write-Host "DEBUG: Changing real current version `"$curVersion`" to fake value"
	$curVersion = "6.6.6.0-fake"
} Else {
	If ( $(Try { (Test-Path variable:local:curVersion) -And (-Not [string]::IsNullOrWhiteSpace($curVersion)) } Catch { $False }) ) {
		$vMsg = "Currently installed version: `"$curVersion`""
		Write-Host "$vMsg" "`r`n"; Write-Log "$vMsg"
	} Else {
		$vMsg = "Could not find Chromium, downloaded installer will setup..."
		Write-Host -ForeGroundColor Yellow "$vMsg"; Write-Log "$vMsg"
		$curVersion = "00.0.0000.000"
	}
}

$cMsg = "Checking: `"$checkSite`", Editor: `"$editor`", Channel: `"$channel`""
Write-Host "Using the folowing settings:`r`n$cMsg`r`n"; Write-Log "$cMsg"

<# MAIN OUTER WHILE LOOP: XML #>
$xml = [xml](Invoke-WebRequest $rssFeed); $i = 0; While ($xml.rss.channel.item[$i]) {
	$editorMatch = 0; $archMatch = 0; $chanMatch = 0; $urlMatch = 0; $hashMatch = 0
	If ($debug -eq 1) {
		Write-Host "DEBUG: $i xml title: $($xml.rss.channel.item[$i].title)"
		Write-Host "DEBUG: $i xml link: $($xml.rss.channel.item[$i].link)"
		<# Write-Host "DEBUG: $i xml description: $($xml.rss.channel.item[$i].description."#cdata-section")" #>
		<# MATCHES: If ($xml.rss.channel.item[$i].title -Match ".*?(Nik)") {$Matches[1]; $editorMatch = 1} #>
		<# MATCHES: If ($debug) {Write-Host "DEBUG: Matches[0], [1]:"; % {$Matches[0]}; % {$Matches[1]}} #>
	}
	<# INNER WHILE LOOP: HTML #>
	$xml.rss.channel.item[$i].description."#cdata-section" | ForEach {
		<# If ($debug) {Write-Host "DEBUG: HTML `$_:`r`n" $_} #>
		If ($_ -Match '(?i)' + $channel + '.*?(Editor: <a href="' + $website + '/">' + $editor + '</a>).*(?i)' + $channel) { $editorMatch = 1 }
		If ($_ -Match '(?i)' + $channel + '.*?(Architecture: 64-bit).*(?i)' + $channel) { $archMatch = 1 }
		If ($_ -Match '(?i)' + $channel + '.*?(Channel: ' + $channel + ')') { $chanMatch = 1 }
		$version = [regex]::Replace($_, '.*(?i)' + $channel + '.*?Version: ([\d.]+).*', '$1')
		$revision = [regex]::Replace($_, '.*(?i)' + $channel + '.*?Revision: (?:<[^>]+>)?(\d{6})<[^>]+>.*', '$1')
		$date = [regex]::Replace($_, '.*(?i)' + $channel + '.*?Date: <abbr title="Date format: YYYY-MM-DD">([\d-]{10})</abbr>.*', '$1')
		$url = [regex]::Replace($_, '.*?(?i)' + $channel + '.*?Download from.*?repository: .*?<li><a href="(' + $fileSrc + '(?:v' + $version + '-r)?' + $revision + '(?:-win64)?/' + $getFile + ')".*', '$1')
		If ($($xml.rss.channel.item[$i].title) -Match "ThumbApps") {
			$getFile = "${getFile}${version}_Dev_32_64_bit.paf.exe"
			$revision = "thumbapps"
			$ignHash = 1
			$url = [regex]::Replace($_, '.*?(?i)' + $channel + '.*?Download from.*?repository: .*?<li><a href="(' + $fileSrc + $getFile + ')".*', '$1')
			$hMsg = "There is no hash provided for this installer"
			Write-Host "$hMsg"; Write-Log "$hMsg"
		}
		If ($ignVer -eq 1) {
			$url = [regex]::Replace($_, '.*?(?i)' + $channel + '.*?Download from.*?repository: .*?<li><a href="(' + $fileSrc + '(?:v[\d.]+-r)?\d{6}(?:-win64)?/' + $getFile + ')".*', '$1')
			$revision = '\d{6}' 
			$vMsg = "Ignoring version mismatch between feed and filename"
			Write-Host -NoNewLine -ForeGroundColor Yellow "`r`n(!) $vMsg"; Write-Log "$vMsg"
		}
		If ($debug -eq 1) {
			 If ($($xml.rss.channel.item[$i].title) -Match $editor) { Write-Host ("{0}`r`n{1}`r`n{0}" -f ("-"*80), "DEBUG: TITLE MATCHES EDITOR") }
			'editor', 'architecture', 'version', 'channel', 'revision', 'date', 'url' | ForEach { Write-Host "DEBUG: $i cdata ${_}:" $(Invoke-Expression `$$_) } 
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
				While ((-Not $host.ui.RawUI.KeyAvailable) -And ($curTime -lt $startTime + $waitTime)) {
					$curTime = Get-Date; $RemainTime = (($startTime - $curTime ).Seconds) + ($waitTime.Seconds)
					Write-Host -ForeGroundColor Yellow -NoNewLine "`r    Waiting $($waitTime.Seconds) seconds before continuing, ${remainTime}s left "
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

If ($debug -eq 1) { 'editorMatch', 'archMatch', 'chanMatch', 'urlMatch', 'hashMatch' | ForEach { Write-Host "DEBUG: ${_}:" $(Invoke-Expression `$$_) }; Write-Host }

<# DOWNLOAD LATEST AND CHECK VERSION #>
$saveAs = "$env:TEMP\$getFile"
If (($editorMatch -eq 1) -And ($archMatch -eq 1) -And ($chanMatch -eq 1) -And ($urlMatch -eq 1) -And ($hashMatch -eq 1)) {
	If (($url) -And ($url -NotMatch ".*$curVersion.*")) {
	$ago = ((Get-Date) - ([DateTime]::ParseExact($date,'yyyy-MM-dd', $null)))
	If ($ago.Days -lt 1) { $agoTxt = ($ago.Hours, "hours") } Else { $agoTxt = ($ago.Days, "days")	}
	Write-Host "New version `"$version`" from $date is available ($agoTxt ago)"; Write-Log "New version `"$version`" from $date is available ($agoTxt ago)"
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
		Write-Log "Latest version already installed"
		Exit 0
	}
} Else {
	$vMsg = "No matching versions found"
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
