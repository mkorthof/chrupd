<# :
@echo off & SETLOCAL & SET "_PS=powershell.exe -NoLogo -NoProfile" & SET "_ARGS=\"%~dp0" %*"
%_PS% "&(Invoke-Command {[ScriptBlock]::Create('$Args=@(&{$Args} %_ARGS%);'+((Get-Content \"%~f0\") -Join [char]10))})"
ENDLOCAL & dir "%~f0.tmp" >nul 2>&1 && move /Y "%~f0" "%~f0.bak" >nul 2>&1 && move /Y "%~f0.tmp" "%~f0" >nul 2>&1 & GOTO :EOF
#>

<# ----------------------------------------------------------------------------
.SYNOPSIS 20210109 MK: Simple Chromium Updater (chrupd.cmd)
<# ----------------------------------------------------------------------------

.DESCRIPTION
  Uses RSS feed from "chromium.woolyss.com" to download and install
  the latest Chromium version, if a newer version is available.

  Options can be set below or using command line arguments. Defaults are:
    - Get the "64bit" "stable" Installer by "Hibbiki"
    - Verify sha1/md5 hash and run installer

.NOTES
  - For easy execution this PowerShell script is embedded in a Batch .CMD
    file using a "polyglot wrapper". Renaming to .ps1 also works.
  - If you add a scheduled task with -crTask, a VBS wrapper is written to
    chrupd.vbs which is used to hide it's window. Use -noVbs to disable.
  - To update chrupd to a newer version just replace this cmd file.

<# ------------------------------------------------------------------------- #>
<# CONFIGURATION:                                                            #>
<# ------------------------------------------------------------------------- #>
<# Make sure the combination of editor and channel is correct.               #>
<# See "chrupd.cmd -h" or README.md for details, more options and settings.  #>
<# ------------------------------------------------------------------------- #>
$cfg = @{
  editor   = "Hibbiki";       <# Editor of Chromium release                  #>
  arch     = "64bit";         <# 32bit or 64bit architecture                 #>
  channel  = "stable";        <# dev, stable                                 #>
  proxy    = "";              <# set <uri> to use a http proxy               #>
  linkArgs = "";              <# see '.\chrupd.cmd -advhelp'                 #>
  log      = $True            <# enable or disable logging <$True|$False>    #>
  cAutoUp  = $True            <# auto update this script <$True|$False>      #>
};
<# END OF CONFIGURATION ---------------------------------------------------- #>


<####################>
<# SCRIPT VARIABLES #>
<####################>

<# NOTE: EA|WA = ErrorAction|WarningAction:
		 0=SilentlyContinue 1=Stop 2=Continue 3=Inquire 4=Ignore 5=Suspend  #>

$_Args = $Args

<# SCRIPTDIR #>
$scriptDir = $_Args[0]
If ( $(Try {
			(Test-Path variable:local:scriptDir) -And	(&Test-Path $scriptDir -EA 4 -WA 4) -And
			(-Not [string]::IsNullOrWhiteSpace($scriptDir))
		} Catch { $False }) ) {
	$rm = ($_Args[0])
	$_Args = ($_Args) | Where-Object { $_ -ne $rm }
} Else {
	$scriptDir = ($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.\'))
}

<# CHRUPD #>
$logFile = $scriptDir + "\chrupd.log"
$scriptName = "Simple Chromium Updater"
$scriptCmd = "chrupd.cmd"
$installLog = "$env:TEMP\chromium_installer.log"
$woolyss = "chromium.woolyss.com"
<# DISABLED: $shaFile = $scriptDir + "\chrupd.sha" #>

If ($PSCommandPath) {
	$scriptCmd = (Get-Item $PSCommandPath).Name
}
If ($MyInvocation.MyCommand.Name) {
	$scriptCmd = $MyInvocation.MyCommand.Name
}

<# CHRUPD VERSION #>
$curScriptDate = (Select-String -Pattern " 202\d{5} " "${scriptDir}\${scriptCmd}") -Replace '.* (202\d{5}) .*', '$1'
If (-Not $curScriptDate) {
	$curScriptDate = 19700101
}

<# CHROMIUM VERSION #>
$curVersion = (Get-ItemProperty -EA 0 -WA 0 HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Chromium).Version

<# DEFAULT VALUES #>
$debug = $fakeVer = $force = $ignVer = $ignHash = 0
$tsMode = $crTask = $rmTask = $shTask = $xmlTask = $manTask = $noVbs = $confirm = 0
$scheduler = $list = $appDir = 0
$proxy = $linkArgs = ""
$cAutoUp = 1

<# ARCHIVE EXTRACT PATHS #>
$arcInstDirs = @(
	"$env:LocalAppData\Chromium\Application",
	"$([Environment]::GetFolderPath('Desktop'))",
	"$env:USERPROFILE\Desktop",
	"$env:TEMP"
)

<# RELEASES: items[$name] = @{ title, editor, source, url, repository, filemask } #>
$items = @{
	"Official"  = @{
		title    = "[0-9]+";
		editor   = "The Chromium Authors";
		fmt      = "XML";
		url      = "https://www.chromium.org";
		repo     = "https://storage.googleapis.com/chromium-browser-snapshots/Win_x64/";
		filemask = "mini_installer.exe";
		alias    = "Chromium"
	};
	"Hibbiki"   =	@{
		title    = "Hibbiki";
		editor   = "Hibbiki";
		fmt      = "XML";
		url      = "https://$woolyss";
		repo     = "https://github.com/Hibbiki/chromium-win64/releases/download/";
		filemask = "mini_installer.sync.exe"
	};
	"Marmaduke" = @{
		title    = "Marmaduke";
		editor   = "Marmaduke";
		fmt      = "XML";
		url      = "https://$woolyss";
		repo     = "https://github.com/macchrome/winchrome/releases/download/";
		filemask = "mini_installer.exe"
	};
	"Ungoogled" = @{
		title    = "Ungoogled";
		editor   = "Marmaduke";
		fmt      = "XML";
		url      = "https://$woolyss";
		repo     = "https://github.com/macchrome/winchrome/releases/download/";
		filemask = "ungoogled-chromium-"
		alias    = "Ungoogled-Marmaduke"
	};
	"RobRich"   =	@{
		title    = "RobRich";
		editor   = "RobRich";
		fmt      = "XML";
		url      = "https://$woolyss";
		repo     = "https://github.com/RobRich999/Chromium_Clang/releases/download/";
		filemask = "mini_installer.exe"
	};
	<# DISABLED: not updated anymore
	"ThumbApps" = @{
		title = "ThumbApps";
		editor = "ThumbApps";
		url = "http://www.thumbapps.org";
		fmt = "XML";
		repo = "https://netix.dl.sourceforge.net/project/thumbapps/Internet/Chromium/";
		filemask = "ChromiumPortable_"
	};	#>
	<# OLD: Chromium-ungoogled (from GH, before Woolyss added it)
	"Chromium-ungoogled" = @{
		editor = "Marmaduke";
		url = "https://github.com/macchrome/winchrome";
		fmt = "JSON";
		repo = "https://api.github.com/repos/macchrome/winchrome/releases";
		filemask = "ungoogled-chromium-";
	};  #>
}

<# WINVER: @(majorVer, minorVer, osType[1=ws,3=server], tsMode) #>

$winVer = @{
	"Windows 10+"            = @(11, 0, 1, 1);
	"Windows 10"             = @(10, 0, 1, 1);
	"Windows 8.1"            = @( 6, 3, 1, 1);
	"Windows 8"              = @( 6, 2, 1, 1);
	"Windows 7"              = @( 6, 1, 1, 2);
	"Windows Vista"          = @( 6, 0, 1, 2);
	"Windows XP 64bit"       = @( 5, 2, 1, 3);
	"Windows XP"             = @( 5, 1, 1, 3);
	"Windows Server 2019"    = @(10, 0, 3, 1);
	"Windows Server 2016"    = @(10, 0, 3, 1);
	"Windows Server 2012 R2" = @( 6, 3, 3, 1);
	"Windows Server 2012"    = @( 6, 2, 3, 1);
	"Windows Server 2008 R2"	= @( 6, 1, 3, 2);
	"Windows Server 2008"    = @( 6, 0, 3, 2);
	"Windows Server 2003"    = @( 5, 2, 3, 3);
}
$osTypeName = @{
	1 = "Workstation";
	2 = "DC";
	3 = "Server";
}
$tsName = @{
	0 = "Auto";
	1 = "Normal";
	2 = "Legacy";
	3 = "Schtasks Command"
}

<# TASK USER MSGS #>
$taskMsg = ${
	$descr	  = "Download and install latest Chromium version";
	$create	  = "Creating Daily Task `"$scriptName`" in Task Scheduler...";
	$failed	  = "Creating Scheduled Task failed.";
	$problem  = "Something went wrong...";
	$exists   = "Scheduled Task already exists.";
	$notfound = "Scheduled Task not found.";
	$remove   = "Removing Daily Task `"$scriptName`" from Task Scheduler...";
	$rmfailed = "Could not remove Task: $scriptName.";
	$notask   = "Scheduled Task already removed.";
	$manual   = "Run `"$scriptCmd -manTask`" for manual instructions";
	$export   = "Run `"$scriptCmd -xmlTask`" to export a Task XML File"
}

$noMatchMsg = @"
Unable to find new version. If settings are correct, it's possible
the script needs to be updated or there could be an issue
with the RSS feed from `"$woolyss`".`r`n
"@

<########>
<# HELP #>
<########>

If ($_Args -iMatch "[-/?]h") {
	Write-Host -NoNewLine "`r`n$scriptName"; Write-Host " ($scriptCmd)"; Write-Host ("-" * 36)"`r`n"
	Write-Host "Uses RSS feed from `"$woolyss`" to install latest Chromium version", "`r`n"
	Write-Host "USAGE: $scriptCmd -[editor|arch|channel|force]"
	Write-Host "`t`t", " -[crTask|rmTask|shTask] or [-list]", "`r`n"
	Write-Host "`t", "-editor  option must be set to one of:"
	Write-Host "`t`t", " <Official|Hibbiki|Marmaduke|Ungoogled|RobRich>"
	Write-Host "`t", "-arch    option must be set to <64bit|32bit>"
	Write-Host "`t", "-channel option must be set to <stable|dev>"
	Write-Host "`t", "-force   always (re)install, even if latest ver is installed", "`r`n"
	Write-Host "`t", "-list    show version, editors and rss feeds from woolyss.com", "`r`n"
	Write-Host "`t", "-crTask  create a daily scheduled task"
	Write-Host "`t", "-shTask  show scheduled task details", "`r`n"
	Write-Host "EXAMPLE: `".\$scriptCmd -editor Marmaduke -arch 64bit -channel stable [-crTask]`"", "`r`n"
	Write-Host "NOTES:   Options `"editor`" and `"channel`" need an argument (CasE Sensive)"
	Write-Host "`t", "See `".\$scriptCmd -advhelp`" for 'advanced' options"
	Exit 0
}

<# ADVANCED HELP #>
If ($_Args -iMatch "[-/?]ad?v?he?l?p?") {
	Write-Host "$scriptName ($scriptCmd)", "`r`n"
	Write-Host "USAGE: $scriptCmd -[tsMode|rmTask|noVbs|confirm]"
	Write-Host "`t`t", " -[proxy|cAutoUp|appDir|linkArgs|ignVer] or [-cUpdate]", "`r`n"
	Write-Host "`t", "-tsMode    *see NOTES below* set option to <1|2|3> or `"auto`""
	Write-Host "`t", "-rmTask    remove scheduled task"
	Write-Host "`t", "-noVbs     do not use vbs wrapper to hide window when creating task"
	Write-Host "`t", "-confirm   answer 'Y' on prompt about removing scheduled task", "`r`n"
	Write-Host "`t", "-proxy     use a http proxy server, set option to <uri> "
	Write-Host "`t", "-cAutoUp   auto update this script, set option to <0|1> (default=1)"
	Write-Host "`t", "-appDir    extract archives to %AppData%\Chromium\Application\`$editor"
	Write-Host "`t", "-linkArgs  option sets <arguments> for chrome.exe in Chromium shortcut"
	Write-Host "`t", "-ignVer    ignore version mismatch between feed and filename", "`r`n"
	Write-Host "`t", "-cUpdate   manually update this script", "`r`n"
	Write-Host "NOTES: Option `"tsMode`" supports these task scheduler modes:"
	Write-Host "`t", "- Unset: OS will be auto detected (Default)"
	Write-Host "`t", "- Or set: 1=Normal (Windows8+), 2=Legacy (Win7), 3=Command (WinXP)"
	Write-Host "      ", "Flags `"xxTask`" can also be used without other settings"
	Write-Host "      ", "All options can be set permanently using variables inside script"
	Exit 0
}

<####################>
<# HANDLE ARGUMENTS #>
<####################>

ForEach ($a in $_Args) {
	<# handle only 'flags', no options with args #>
	$flags = "[-/](force|fakeVer|list|rss|crTask|rmTask|shTask|xmlTask|manTask|noVbs|confirm|scheduler|ignHash|ignVer|cUpdate|appDir)"
	If ($match = $(Select-String -CaseSensitive -Pattern $flags -AllMatches -InputObject $a)) {
		Invoke-Expression ('{0}="{1}"' -f ($match -Replace "^-", "$"), 1);
		$_Args = ($_Args) | Where-Object { $_ -ne $match }
	}
}
If (($_Args.length % 2) -eq 0) {
	$i = 0
	While ($_Args -Is [Object[]] -And $i -lt $_Args.length) {
		<# OLD: $i = 0; While ($i -lt $_Args.length) { #>
		If ((($_Args[$i] -Match "^-debug") -And ($_Args[($i + 1)] -Match "^\d")) -Or (($_Args[$i] -Match "^-") -And ($_Args[($i + 1)] -Match "^[\w\.]"))) {
			Invoke-Expression ('{0}="{1}"' -f ($_Args[$i] -Replace "^-", "$"), ($_Args[++$i] | Out-String).Trim());
		}
		$i++
	}
} Else {
	Write-Host -ForegroundColor Red "Invalid options specfied. Try `"$scriptCmd -h`" for help, exiting...`r`n"
	Exit 1
}

<# INLINE SCRIPT CONFIG #>
If (!$editor -And $cfg.editor) {
	$editor = $cfg.editor
}
If (!$channel -And $cfg.channel) {
	$channel = $cfg.channel
}
If (!$arch -And $cfg.arch) {
	$arch = $cfg.arch
}
If (!$proxy -And $cfg.proxy) {
	$proxy = $cfg.proxy
}
If (!$cAutoUp -And ($cfg.cAutoUp -eq $True)) {
	$cAutoUp = 1
}
If ($cfg.linkArgs) {
	$srcExeArgs = $cfg.linkArgs
}

If ($proxy) {
	$PSDefaultParameterValues.Add("Invoke-WebRequest:Proxy", "$proxy")
	$webproxy = New-Object System.Net.WebProxy
	$webproxy.Address = $proxy
}

If ($linkArgs) {
	$srcExeArgs = $linkArgs
}

<# ALIAS #>
$items.GetEnumerator() | ForEach-Object {
	If ($_.Value.alias -eq $editor ) {
		$editor = $_.Key
	}
}
@{ "32bit|32|x86" = "32-bit";
	"64bit|64|x64"   = "64-bit";
}.GetEnumerator() | ForEach-Object {
	If ($_.Key -Match $arch) { $arch = $_.Value }
}

<# GET WINDOWS VERSION #>
$getWinVer = {
	param(
		[hashtable]$winVer,
		[hashtable]$osTypeName,
		[int]$tsMode
	)
	<# DEBUG: TEST WINVER
	If ($debug -ge 3) {
		$osVer = @{ Major = 6; Minor = 1; }
		$osType = 3
	} #>
	$osFound = $False
	$osVer = (([System.Environment]::OSVersion).Version)
	[int]$osType = (Get-CIMInstance Win32_OperatingSystem).ProductType
	$winVer.GetEnumerator() | ForEach-Object {
		If ( ($(($osVer).Major) -eq $($_.Value[0])) -And ($(($osVer).Minor) -eq $($_.Value[1])) -And ($($osType) -eq $($_.Value[2])) ) {
			$osFound = $True
			$osFullName = ("`"{0}`" ({1}.{2}, {3})" -f $_.Key, ($osVer).Major, ($osVer).Minor, $osTypeName[$osType])
			$osTsMode = $_.Value[3]
			Return $osFound, $osFullName, $osTsMode
		}
	} | Out-Null
If (-Not $osFound) {
		$osFullName = "Unknown Windows Version"
	}
	If ($tsMode -NotMatch '^[1-3]$') {
		If ($osFound) {
			$tsMode = $osTsMode
		} Else {
			$tsMode = 3
		}
	}
	Return $osFullName, $tsMode
}

<#############>
<# FUNC: MSG #>
<#############>

<# OLD: Function Write-Err ($msg) {
	Write-Host -ForeGroundColor Red "ERROR: $msg"
} #>
<# OLD: Function Write-Log ($msg) {
	If ($cfg.log) {
		Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " $msg")
	}
} #>

<# SYNTAX: #>
<# Write-Msg [-o dbg,(int)lvl|err|wrn|log|nnl|tee|bgColor|fgColor] "Text 123" #>

Function Write-Msg {
	[CmdletBinding()]
	param (
		[alias("f")]
		$options,
		[Parameter(Position = 1)]
		$msg
	)
	$dbg = $log = $tee = $False
	$lvl = 0
	$params = @{}
	$cnt = 0
	ForEach ($opt in $options) {
		switch -Regex ($opt) {
			'dbg' { $pf = "DEBUG: "; $dbg = $True; }
			'warn' { $pf = "WARNING: "; $params += @{ForegroundColor = "Yellow" } }
			'err' { $pf = "ERROR: "; $params += @{ForegroundColor = "Red" } }
			'nnl' { $params += @{NoNewLine = $True } }
			'log' { $log = $True }
			'tee' { $tee = $True }
			'^[0-9]$'	{ $lvl = $($matches[0]) }
			'^(?-i:[A-Z][a-zA-Z]{2,})' {
				If ($cnt -ge 1) {
					$params += @{BackgroundColor = $($matches[0]) }
				} Else {
					$params += @{ForegroundColor = $($matches[0]) }
				}
				$cnt++
			}
		}
	}
	<# log to stdout (check debug level) and/or log to file with date #>
	If (!$log -And ((!$dbg) -Or (($dbg) -And ($debug -ge $lvl)))) {
		Write-Host @params ("{0}$msg" -f $pf)
	}
	If ($cfg.log -And ($log -Or $tee)) {
		Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " $msg")
	}
}

<# OPTION: LIST #>

<# SHOW VERSION, EDITORS, RSS & EXIT #>
If ($list -eq 1) {
	Write-Msg
	Write-Msg -o nnl "Currently installed Chromium version: "
	Write-Msg $curVersion
	Write-Msg "`r`n"
	Write-Msg "Available Editors:"
	<#$items.GetEnumerator() | Where-Object Value | Format-Table @{l='editor:';e={$_.Key}}, @{l='website, repository, file:';e={$_.Value}} -AutoSize#>
	$items.GetEnumerator() | Where-Object Value | `
		Format-Table @{l = 'Name'; e = { $_.Key } }, `
	@{l = 'Editor'; e = { $_.Value.editor } }, `
	@{l = 'Website'; e = { $_.Value.url } }, `
	@{l = 'Repository'; e = { $_.Value.repo } }, `
		<# @{l='Format';e={$_.Value.fmt}}, ` #>
	@{l = 'Filemask'; e = { $_.Value.filemask } } -AutoSize
	Write-Msg "Available from Woolyss RSS Feed:"
	$xml = [xml](Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Uri "https://${woolyss}/feed/windows-$($arch)")
	$xml.rss.channel.Item | Select-Object @{N = 'Title'; E = 'title' }, @{N = 'Link'; E = 'link' } | Out-String
	Exit 0
}

<# SHOW SCRIPT TITLE #>
Write-Msg -o nnl,White,DarkGray " $scriptName"
Write-Msg -o nnl,Black,DarkGray " ( $scriptCmd $curScriptDate ) "
Write-Msg "`r`n"
# Write-Msg -o Black $(("-" * 36)"`r`n")

$osFullName, $tsMode = $getWinVer.Invoke($winVer, $osTypeName, [int]$tsMode)
Write-Msg ("OS Detected: {0}`r`nTask Scheduler Mode: {1} `"{2}`"" -f $osFullName, ${tsMode}, $($tsName.[int]$tsMode))

<##############>
<# CHECK ARGS #>
<##############>

<# CHECK LOGFILE #>
If ($cfg.log) {
	If ( $(Try { (Test-Path variable:local:logFile) -And (-Not [string]::IsNullOrWhiteSpace($logFile)) } Catch { $False }) ) {
		Write-Msg "Logging to: `"$logFile`""
	} Else {
		$cfg.log = $False
		Write-Msg "Unable to open logfile, output to console only`r`n"
	}
}

<# MANDATORY ARGS #>
<# OLD: If (-Not ($items.values.editor -eq $editor)) #>
If (-Not ($items.Keys -eq $editor)) {
	Write-Msg -o err "Editor setting incorrect `"$editor`" (CasE Sensive). Exiting ..."
	Exit 1
} Else {
	$items.GetEnumerator() | ForEach-Object {
		If ($_.Value.editor -eq $editor) {
			If ($_.value.fmt -cNotMatch "^(XML|JSON)$") {
				Write-Msg -o err "Invalid format `"${items[$editor].fmt}`", must be `"XML`" or `"JSON`". Exiting ..."
				Exit 1
			}
		}
	}
}
If ($arch -cNotMatch "^(32-bit|64-bit)$") {
	Write-Msg -o err "Invalid architecture `"$arch`", must be `"32-bit`" or `"64-bit`". Exiting ..."
	Exit 1
}
If ($channel -cNotMatch "^(stable|dev)$") {
	Write-Msg -o err "Invalid channel `"$channel`", must be `"stable`" or `"dev`" (CasE Sensive). Exiting ..."
	Exit 1
}
If ($cAutoUp -NotMatch "^(0|1)$") {
	Write-Msg -o warn,tee "Invalid AutoUpdate setting `"$cAutoUp`", must be 0 or 1"
}

<#################>
<# UPDATE SCRIPT #>
<#################>

<# FUNC: SPLIT #>

<# splits header and config from script content #>
<# - input  : <content>  (not filename) #>
<# - output : result  #>

Function doSplit ($content) {
	$lnCfgStart = ($content | Select-String -Pattern "<# CONFIGURATION:? \s+ #>").LineNumber
	$lnCfgEnd = ($content | Select-String -Pattern "<# END OF CONFIGURATION ?[#-]+ ?#>").LineNumber
	$result = @{}
	If (($lnCfgStart -gt 1) -And ($lnCfgEnd -gt 1)) {
		$result.head = $content | Select-Object -Index (0..(${lnCfgStart} - 2))
		$result.config = $content | Select-Object -Index ((${lnCfgStart} - 1)..$(${lnCfgEnd} - 1))
		$lineCount = ($content).Count
		$lastLine = $content | Select-Object -Skip (${lineCount} - 1)
		If ($lineCount -And $lastLine -eq "") {
			$lineCount = ${lineCount} - 2
		}
		$result.script = $content | Select-Object -Index ($lnCfgEnd..$lineCount)
		$result.hash = (Get-FileHash -Algorithm SHA1 -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes((($result.script)))))).Hash
	} Else {
		Return $False
	}
	$result
}

<# FUNC: UPDATE SCRIPT #>

Function updateScript () {
	$params = @{}
	<# TEST: $params += @{ Verbose = $True } #>
	If ($debug -ge 1) {
		$params += @{ WhatIf = $True }
		Write-Msg -o dbg,1 "updateScript (!) not changing files (!)"
	}
	<# get date/version from readme #>
	[System.Net.ServicePointManager]::SecurityProtocol = @("Tls12", "Tls11", "Tls")
	$ghApi = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("aHR0cHM6Ly9hcGkuZ2l0aHViLmNvbS9yZXBvcy9ta29ydGhvZi9jaHJ1cGQ="))
	$ghJson = (ConvertFrom-Json(Invoke-WebRequest -UseBasicParsing -TimeoutSec 300 -Uri "$ghApi/contents/README.md"))
	$ghReadmeContent = [System.Text.Encoding]::UTF8.GetString(([System.Convert]::FromBase64String((($ghJson).content)))) -split "`n"
	$newDate = ($ghReadmeContent | Select-String -Pattern "Latest version.* 202\d{5} ") -Replace '.*Latest version: (202\d{5}) .*', '$1'
	Write-Msg -o dbg,1 "updateScript curScriptDate=$curScriptDate newDate=$newDate"
	<# compare date in remote README.md with local chdupd.cmd script #>
	If ($newDate -And (([DateTime]::ParseExact($newDate, 'yyyyMMdd', $null)) -gt ([DateTime]::ParseExact($curScriptDate, 'yyyyMMdd', $null)))) {
		Write-Msg -o tee "New chrupd version `"$newDate`" available, updating script..."
		<# SPLIT: current script file #>
		Write-Msg -o dbg,1 "updateScript doSplit `$scriptCmd=`"$scriptCmd`""
		$loSplit = doSplit $(Get-Content "${scriptDir}\${scriptCmd}")
		<# SPLIT: new script content #>
		Write-Msg -o dbg,1 "updateScript getting chrupd contents from api.github.com"
		$ghJson = (ConvertFrom-Json(Invoke-WebRequest -UseBasicParsing -TimeoutSec 300 -Uri "$ghApi/contents/chrupd.cmd"))
		$ghContent = [System.Text.Encoding]::UTF8.GetString(([System.Convert]::FromBase64String((($ghJson).content)))) -split "`r`n"
		Write-Msg -o dbg,1 "updateScript doSplit `"`$ghContent`""
		If ($debug -ge 1) {
			doSplit $ghContent
		}
		If ($ghContent) {
			$ghSplit = doSplit $ghContent
		} Else {
			Write-Msg -o err,tee "Could not download new script, skipped update"
			Break
		}
		<# merge current local config if found, else just write new script #>
		If ($ghSplit) {
			If ($loSplit) {
				$newContent = $ghSplit.head, $loSplit.config, $ghSplit.script
				Write-Msg -o dbg,1 "updateScript loSplit.hash=$($loSplit.hash) ghSplit.hash=$($ghSplit.hash)"
			} Else {
				$newContent = $ghContent
				Write-Msg -o warn "Current script configuration not found, using defaults"
			}
			If ( $(Try { (&Test-Path "${scriptDir}\${scriptCmd}.tmp") } Catch { $False }) ) {
				Write-Msg -o dbg,1 "${scriptCmd}.tmp already exists, removing..."
				Try {
					Remove-Item @params -ErrorAction 1 -WarningAction 1 "${scriptDir}\${scriptCmd}.tmp" -Force
				} Catch {
					Write-Msg -o err,tee "Could not remove ${scriptCmd}.tmp"
					Break
				}
			}
			Try {
				Set-Content @params -EA 1 -WA 1 "${scriptDir}\${scriptCmd}.tmp" -Value $newContent
			} Catch {
				Write-Msg -o err,tee "Could not write script, skipped update"
				Break
			}
			<# only replacing in use script if we're running as ps1 (chrupd.ps1) #>
			If ($scriptCmd.Split(".")[1] -eq "ps1") {
				Try {
					Move-Item @params -Force -EA 0 -WA 0 -Path "${scriptDir}\${scriptCmd}" -Destination "${scriptDir}\${scriptCmd}.bak"
				} Catch {
					Write-Msg -o err,tee "Could not move `"${scriptCmd}`" to `"$contentCmd.bak`""
					Break
				}
				Try {
					Move-Item @params -Force -EA 0 -WA 0 -Path "${scriptDir}\${scriptCmd}.tmp" -Destination s"${scriptDir}\${scriptCmd}"
				} Catch {
					Write-Host -o err,tee "Could not move `"${scriptCmd}.tmp`" to `"$contentCmd`""
					Break
				}
			}
		} Else {
			Write-Msg -o err,tee "Unable to read new script, skipped update"
			Break
		}
	} Else {
		If ($cUpdate) {
			Write-Msg "No script updates available "
			Write-Msg
		} Else {
			Write-Msg -o dbg,1 "updateScript no updates available "
		}
	}
}

<# OPTION: CHRUPD UPDATE #>

If ($cUpdate) {
	updateScript
	Exit
}

<# chrupd auto update #>
If ($cAutoUp -eq 1) {
	updateScript
}

<###################>
<# SCHEDULED TASKS #>
<###################>

<# 1) Normal (Windows 8+), uses Cmdlets [default]   #>
<# 2) Legacy (Windows 7), uses COM object           #>
<# 3) Command (Windows XP), uses schtasks.exe       #>

<# TASK VARS #>
$confirmParam = $True
If ( $(Try { -Not (Test-Path variable:local:tsMode) -Or ([string]::IsNullOrWhiteSpace($tsMode)) } Catch { $False }) ) {
	$tsMode = 1
}
$vbsWrapper = $scriptDir + "\chrupd.vbs"
$taskArgs = "-scheduler -editor $($items[$editor].editor) -arch $arch -channel $channel -cAutoUp $AutoUp"
If ($noVbs -eq 0) {
	$taskCmd = "$vbsWrapper"
} Else {
	$taskCmd = 'powershell.exe'
	$taskArgs = "-ExecutionPolicy ByPass -NoLogo -NoProfile -WindowStyle Hidden $scriptCmd $taskArgs"
}

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

<# TASK XML #>
$xmlContent = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>$($taskMsg.descr)</Description>
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

<# CRTASK: CREATE SCHEDULED TASK #>
If ($crTask -eq 1) {
	If ( $(Try { -Not (&Test-Path $vbsWrapper) } Catch { $False }) ) {
		Write-Msg "VBS Wrapper ($vbsWrapper) missing, creating...`r`n"
		Set-Content $vbsWrapper -ErrorAction Stop -WarningAction Stop -Value $vbsContent
		If ( $(Try { -Not (&Test-Path $vbsWrapper) } Catch { $False }) ) {
			Write-Msg "Could not create VBS Wrapper, try again or use `"-noVbs`" to skip"
			Exit 1
		}
	}
	Switch ($tsMode) {
		<# CRTASK: 1 NORMAL MODE #>
		1 {
			$action = New-ScheduledTaskAction -Execute $taskCmd -Argument "$taskArgs" -WorkingDirectory "$scriptDir"
			$trigger = New-ScheduledTaskTrigger -RandomDelay (New-TimeSpan -Hour 1) -Daily -At 17:00
			If (-Not (&Get-ScheduledTask -EA 0 -TaskName "$scriptName")) {
				Write-Msg $($taskMsg.create)
				Try { (Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "$scriptName" -Description "$taskMsg.descr") | Out-Null }
				Catch { Write-Msg "$($taskMsg.problem)`r`nError: `"$($_.Exception.Message)`"" }
			} Else {
				Write-Msg $($taskMsg.exists)
			}
			If (&Get-ScheduledTask -EA 0 -TaskName "$scriptName" -OutVariable task) {
				If ( $(Try { (Test-Path variable:local:task) -And (-Not [string]::IsNullOrWhiteSpace($task)) } Catch { $False }) ) {
					Write-Msg ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}`r`n" -f ($task).TaskPath, ($task).TaskName, ($task).Description, ($task).State)
				} Else {
					Write-Msg $taskMsg.failed
				}
			} Else {
				Write-Msg ("{0}`r`n`r`n  {1}`r`n  {2}`r`n" -f $taskMsg.failed, $taskMsg.manual, $taskMsg.export)
			}
		}
		<# CRTASK: 2 LEGACY MODE #>
		2 {
			$taskService = New-Object -ComObject("Schedule.Service")
			$taskService.Connect()
			$taskFolder = $taskService.GetFolder("\")
			If (-Not $(Try { $taskFolder.GetTask("$scriptName") } Catch { $False }) ) {
				Write-Msg $taskMsg.create
				$taskDef = $taskService.NewTask(0)
				$taskDef.RegistrationInfo.Description = "$TaskDescr"
				$taskDef.Settings.Enabled = $True
				$taskDef.Settings.AllowDemandStart = $True

				$trigCollection = $taskDef.Triggers
				$trigger = $trigCollection.Create(2)

				$trigger.StartBoundary = ((Get-Date).toString("yyyy-MM-dd'T'17:00:00"))
				$trigger.RandomDelay = "PT1H"
				$trigger.DaysInterval = 1
				$trigger.Enabled = $True

				$execAction = $taskDef.Actions.Create(0)
				$execAction.Path = "$taskCmd"
				$execAction.Arguments = "$taskArgs"
				$execAction.WorkingDirectory = "$scriptDir"
				Try { $_t = $taskFolder.RegisterTaskDefinition("$scriptName", $taskDef, 6, "", "", 3, "") }
				Catch { Write-Msg "$($taskMsg.problem) Error: `"$($_.Exception.Message)`"" }
				If ( $(Try { -Not (Test-Path variable:local:_t) -Or ( [string]::IsNullOrWhiteSpace($_t)) } Catch { $False }) ) {
					Write-Msg ("{0}`r`n`r`n  {1}`r`n  {2}`r`n" -f $taskMsg.failed, $taskMsg.manual, $taskMsg.export)
				}
			} Else {
				Write-Msg $taskMsg.exists
			}
			If ( $(Try { $taskFolder.GetTask("$scriptName") } Catch { $False }) ) {
				$task = $taskFolder.GetTask("$scriptName")
				Write-Msg ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}.`r`n" -f $($task.Path), "", $($task.Definition.RegistrationInfo.Description), $($task.State))
			}
		}
		<# CRTASK: 3 CMD MODE #>
		3 {
			Write-Msg "$($taskMsg.create)`r`n"
			Write-Msg "Creating Task XML File..."
			Set-Content "$env:TEMP\chrupd.xml" -Value $xmlContent
			<# $delay = (Get-Random -minimum 0 -maximum 59).ToString("00") #>
			<# $a = "/Create /SC DAILY /ST 17:${delay} /TN \\`"$scriptName`" /TR `"'$vbsWrapper' $taskArgs`"" #>
			$a = "/Create /TN \\`"$scriptName`" /XML `"$env:TEMP\chrupd.xml`""
			If ($confirm -eq 1) {
				$a = "$a /F"
			}
			$p = Start-Process -FilePath "$env:SystemRoot\system32\schtasks.exe" -ArgumentList $a -Wait -NoNewWindow -PassThru
			$handle = $p.Handle
			$p.WaitForExit()
			If ($p.ExitCode -eq 0) {
				Write-Msg
			} Else {
				Write-Msg ("`r`n{0}`r`n`r`n  {1}`r`n  {2}`r`n" -f $taskMsg.failed, $taskMsg.manual, $taskMsg.export)
			}
			Try {
				Remove-Item -EA 0 -WA 0 -Force "$env:TEMP\chrupd.xml"
			} Catch {
				$False
			}
			Write-Msg dbg, 1 "handle=$handle"
		}
	}
	Exit 0
	<# RMTASK: REMOVE SCHEDULED TASK #>
} ElseIf ($rmTask -eq 1) {
	Switch ($tsMode) {
		<# RMTASK: 1 NORMAL MODE #>
		1 {
			If ($confirm -eq 1) { $confirmParam = $False }
			If (&Get-ScheduledTask -EA 0 -TaskName "$scriptName") {
				Write-Msg "$($taskMsg.remove)`r`n"
				Try {
					UnRegister-ScheduledTask -confirm:${confirmParam} -TaskName "$scriptName"
				} Catch {
					Write-Msg "${taskMsg.problem}... $($_.Exception.Message)"
				}
			} Else {
				Write-Msg "$($taskMsg.notask)`r`n"
			}
			If (&Get-ScheduledTask -EA 0 -TaskName "$scriptName" -OutVariable task) {
				If ( $(Try { (Test-Path variable:local:task) -And (-Not [string]::IsNullOrWhiteSpace($task)) } Catch { $False }) ) {
					Write-Msg ("Could not remove Task: `"{0}{1}`", Description: `"{2}`", State: {3}`r`n" -f ($task).TaskPath, ($task).TaskName, ($task).Description, ($task).State)
					Write-Msg ("{0}`r`n`r`n{1}`r`n" -f $taskMsg.rmfailed, $taskMsg.manual)
				}
			}
		}
		<# RMTASK: 2 LEGACY MODE #>
		2 {
			$taskService = New-Object -ComObject("Schedule.Service")
			$taskService.Connect()
			$taskFolder = $taskService.GetFolder("\")
			If ( $(Try { $taskFolder.GetTask("$scriptName") } Catch { $False }) ) {
				Write-Msg "$taskMsg.remove`r`n"
				Try { $taskFolder.DeleteTask("$scriptName", 0) } Catch { Write-Msg "${taskMsg.problem}... $($_.Exception.Message)" }
			} Else {
				Write-Msg "$($taskMsg.notask)`r`n"
			}
			If ( $(Try { $taskFolder.GetTask("$scriptName") } Catch { $False }) ) {
				$task = $taskFolder.GetTask("$scriptName")
				Write-Msg ("Could not remove Task: `"{0}{1}`", Description: `"{2}`", State: {3}`r`n" -f "", ($task).TaskName, ($task).Description, ($task).State)
				Write-Msg ("{0}`r`n`r`n{1}`r`n" -f $taskMsg.rmfailed, $taskMsg.manual)
			}
		}
		<# RMTASK: 3 COMMAND MODE #>
		3 {
			Write-Msg "$taskMsg.remove`r`n"
			$a = "/Delete /TN \\`"$scriptName`""
			$p = Start-Process -FilePath "$env:SystemRoot\system32\schtasks.exe" -ArgumentList $a -Wait -NoNewWindow -PassThru
			$handle = $p.Handle
			$p.WaitForExit()
			If ($p.ExitCode -eq 0) {
				Write-Msg
			} Else {
				Write-Msg ("{0}`r`n`r`n{1}`r`n" -f $taskMsg.rmfailed, $taskMsg.manual)
			}
		}
	}
	Exit 0
	<# SHTASK: SHOW SCHEDULED TASK #>
} ElseIf ($shTask -eq 1) {
	Switch ($tsMode) {
		<# SHTASK: 1 NORMAL MODE #>
		1 {
			If (&Get-ScheduledTask -EA 0 -TaskName "$scriptName" -OutVariable task) {
				If ( $(Try { (Test-Path variable:local:task) -And (-Not [string]::IsNullOrWhiteSpace($task)) } Catch { $False }) ) {
					$taskinfo = (&Get-ScheduledTaskInfo -TaskName "$scriptName")
					Write-Msg ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}." -f ($task).TaskPath, ($task).TaskName, ($task).Description, ($task).State)
					Write-Msg ("Actions: WorkingDirectory: `"{0}`", Execute: `"{1}`", Arguments: `"{2}`"" -f ($task).actions.WorkingDirectory, ($task).actions.Execute, ($task).actions.Arguments)
					Write-Msg ("TaskInfo: LastRunTime: `"{0}`", NextRunTime: `"{1}`", NumberOfMissedRuns: {2}`r`n" -f ($taskinfo).LastRunTime, ($taskinfo).NextRunTime, ($taskinfo).NumberOfMissedRuns)
				}
			} Else {
				Write-Msg "$($taskMsg.notfound)`r`n"
			}
		}
		<# SHTASK: 2 LEGACY MODE #>
		2 {
			$taskService = New-Object -ComObject("Schedule.Service")
			$taskService.Connect()
			$taskFolder = $taskService.GetFolder("\")
			If ( $(Try { $taskFolder.GetTask("$scriptName") } Catch { $False }) ) {
				$task = $taskFolder.GetTask("$scriptName")
				Write-Msg ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}." -f $($task.Path), "", $($task.Definition.RegistrationInfo.Description), $($task.State))
				Write-Msg ("Actions: WorkingDirectory: `"{0}`", Execute: `"{1}`", Arguments: `"{2}`"" -f $($($task.Definition.Actions).WorkingDirectory), $($($task.Definition.Actions).Path), $($($task.Definition.Actions).Arguments))
				Write-Msg ("TaskInfo: LastRunTime: `"{0}`", NextRunTime: `"{1}`", NumberOfMissedRuns: {2}`r`n" -f $($task.LastRunTime), $($task.NextRunTime), $($task.NumberOfMissedRuns))
			} Else {
				Write-Msg "$($taskMsg.notfound)`r`n"
			}
		}
		<# SHTASK: 3 CMD MODE #>
		3 {
			$a = "/Query /TN \\`"${scriptName}`" /XML"
			<# $p = Start-Process -FilePath "$env:SystemRoot\system32\schtasks.exe" -ArgumentList $a -Wait -NoNewWindow -PassThru #>
			<# $handle = $p.Handle	#>
			<# $p.WaitForExit() #>
			$pinfo = New-Object System.Diagnostics.ProcessStartInfo
			$pinfo.FileName = "$env:SystemRoot\system32\schtasks.exe"
			$pinfo.RedirectStandardError = $True
			$pinfo.RedirectStandardOutput = $True
			$pinfo.UseShellExecute = $False
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
				Write-Msg ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}." -f $($stdout.Task.RegistrationInfo.URI), "", $($stdout.Task.RegistrationInfo.Description), $State)
				Write-Msg ("Actions: WorkingDirectory: `"{0}`", Execute: `"{1}`", Arguments: `"{2}`"" -f $($stdout.Task.Actions.Exec.WorkingDirectory), $($stdout.Task.Actions.Exec.Command), $($stdout.Task.Actions.Exec.Arguments))
				Write-Msg ("TaskInfo: LastRunTime: `"{0}`", NextRunTime: `"{1}`", NumberOfMissedRuns: {2}`r`n" -f $LastRunTime, $NextRunTime, "?")
			} Else {
				Write-Msg "$($taskMsg.notfound)`r`nError: $stderr"
			}
		}
	}
	Exit 0
	<# CREATE TASK MANUALLY #>
} ElseIf ($manTask -eq 1) {
	Write-Msg "Check settings and retry, use a different tsMode (see help)"
	Write-Msg "Or try manually by going to: `"Start > Task Scheduler`" or `"Run taskschd.msc`".`r`n"
	Write-Msg "These settings can be used when creating a New Task :`r`n"
	Write-Msg ("  Name: `"{0}`"`r`n    Description `"{1}`"`r`n    Trigger: Daily 17:00 (1H random delay)`r`n    Action: `"{2}`"`r`n    Arguments: `"{3}`"`r`n    WorkDir: `"{4}`"`r`n" `
			-f $scriptName, $taskMsg.descr, $taskCmd, $taskArgs, $scriptDir)
	Exit 0
	<# EXPORT TASK (XML) #>
} ElseIf ($xmlTask -eq 1) {
	Set-Content "$env:TEMP\chrupd.xml" -Value $xmlContent
	If ( $(Try { (&Test-Path "$env:TEMP\chrupd.xml") } Catch { $False }) ) {
		Write-Msg "Exported Task XML File to: `"$env:TEMP\chrupd.xml`""
		Write-Msg "File can be imported in Task Scheduler or `"schtasks.exe`".`r`n"
	} Else {
		Write-Msg "Could not export XML"
	}
	Exit 0
}

<# END SCHEDULED TASKS #>

Write-Msg -o log "Start (pid:$pid name:$($(Get-PSHostProcessInfo | Where-Object ProcessId -eq $pid).ProcessName) scheduler:$scheduler v:$curScriptDate )"

<# VERIFY CURRENT CHROME VERSION #>
If (!$curVersion) {
	$curVersion = (Get-ChildItem ${env:LocalAppData}\Chromium\Application -EA 0 -WA 0 |
		Where-Object { $_.Key -Match "\d\d.\d.\d{4}\.\d{1,3}" } ).Key | 
	Sort-Object | Select-Object -Last 1
}
If ($force -eq 1) {
	Write-Msg -o tee "Forcing update, ignoring currently installed Chromium version `"$curVersion`""
	Write-Msg
	$curVersion = "00.0.0000.000"
} ElseIf ($fakeVer -eq 1) {
	Write-Msg -o dbg,0 "Changing real current Chromium version `"$curVersion`" to fake value"
	$curVersion = "6.6.6.0-fake"
} Else {
	If ( $(Try { (Test-Path variable:local:curVersion) -And (-Not [string]::IsNullOrWhiteSpace($curVersion)) } Catch { $False }) ) {
		Write-Msg
		Write-Msg -o tee "Currently installed Chromium version: `"$curVersion`""
		Write-Msg
	} Else {
		Write-Msg -o warn,tee "Could not find Chromium, initial installation will be done by the downloaded installer..."
		$curVersion = "00.0.0000.000"
	}
}

Write-Msg "Using the following settings:"
$i = 0
$_arr = $('Feed', 'name', 'editor', 'architecture', 'channel')
ForEach ($_conf in $woolyss, $(($items.GetEnumerator() | Where-Object { $_.Key -eq $editor }).Name), $($items[$editor].editor), $arch, $channel) {
	Write-Msg -o nnl $_arr[$i]
	Write-Msg -o nnl ' "'
	Write-Msg -o nnl,DarkGray $_conf
	Write-Msg -o nnl '" '
	$cMsg += '{0} "{1}" ' -f $_arr[$i], $_conf
	$i++
}
Write-Msg "`r`n"
Write-Msg -o log "$cMsg"

<#############>
<# FUNCTIONS #>
<#############>

<# FUNC: VALIDATE HASH FORMAT #>

Function checkHashFmt ($cdataObj) {
	# DEBUG: `$if ($debug -ge 1) { Write-Msg dbg,1 "hash = $($cdataObj.hash)"; } #Exit
	If ($ignHash -eq 0) {
		If (($cdataObj.hashAlgo -Match "md5|sha1") -And ($cdataObj.hash -Match "[0-9a-f]{32}|[0-9a-f]{40}")) {
			$cdataObj.hashFmtMatch = $True
		} Else {
			Write-Msg -o tee,err "No valid hash for installer/archive found, exiting..."
			Exit 0
		}
		Write-Msg -o dbg,1 "`$i=$i checkHashFmt cdataObj.hash=$($cdataObj.hash)`r`n"
	} Else {
		<# PROMPT USER #>
		$_hMsg = "Ignoring hash. Could not verify checksum of installer/archive."
		Write-Msg -o Yellow "`r`n(!) ${_hMsg}`r`n    Press any key to abort or `"c`" to continue...`r`n"
		Write-Msg -o log "$_hMsg"
		$host.UI.RawUI.FlushInputBuffer()
		$startTime = Get-Date; $waitTime = New-TimeSpan -Seconds 30
		While ((-Not $host.ui.RawUI.KeyAvailable) -And ($curTime -lt ($startTime + $waitTime))) {
			$curTime = Get-Date
			$RemainTime = (($startTime - $curTime) + $waitTime).Seconds
			Write-Msg -o nnl,Yellow "`r    Waiting $($waitTime.TotalSeconds) seconds before continuing, ${remainTime}s left "
		}
		Write-Msg
		If ($host.ui.RawUI.KeyAvailable) {
			$x = $host.ui.RawUI.ReadKey("IncludeKeyDown, NoEcho")
			If ($x.VirtualKeyCode -ne "67") {
				Write-Msg -o tee "Aborting..."
				Exit 1
			}
		}
		$cdataObj.hashFmtMatch = $True
		$cdataObj.hash = $null
		$cdataObj.hashAlgo = $null
	}
	$cdataObj
}

<# CHECK IF 7ZIP IS PRESENT #>
$get7z = {
	$7z = ""
	$7zPaths = @(
		"7z.exe",
		"7za.exe",
		"$env:ProgramFiles\7-Zip\7z.exe",
		"$env:ProgramData\chocolatey\tools\7z.exe"
		"$env:ProgramData\chocolatey\bin\7z.exe"
	)
	$7zUrls = @{
		"7zip.org"         = @{
			url  = "https://www.7-zip.org/a/7za920.zip"
			hash = "2A3AFE19C180F8373FA02FF00254D5394FEC0349F5804E0AD2F6067854FF28AC"
		}
		"github-chromium"  = @{
			url  = "https://github.com/chromium/chromium/raw/master/third_party/lzma_sdk/Executable/7za.exe";
			hash = "F5D52F0AC0CF81DF4D9E26FD22D77E2D2B0F29B1C28F36C6423EA6CCCB63C6B4"
		};
		"googlesource.com" = @{
			url  = "https://chromium.googlesource.com/chromium/src/+/master/third_party/lzma_sdk/Executable/7za.exe?format=TEXT";
			hash = "F5D52F0AC0CF81DF4D9E26FD22D77E2D2B0F29B1C28F36C6423EA6CCCB63C6B4"
		};
		"chocolatey.org"   = @{
			url  = "https://chocolatey.org/7za.exe";
			hash = "8E679F87BA503F3DFAD96266CA79DE7BFE3092DC6A58C0FE0438F7D4B19F0BBD"
		};
	}
	$cnt = 0;
	ForEach ($7z in $7zPaths) {
		If (($7z -ne "") -And (Test-Path $7z -pathType Leaf -EA 0 -WA 0)) {
			$cnt++
			Break
		}
	}
	<# IF NEEDED DOWNLOAD 7ZA.EXE #>
	If ($cnt -lt 1) {
		$i = 1
		$7zUrls.GetEnumerator() | ForEach-Object {
			Write-Msg -o tee "Could find `"7za.exe`", downloading from `"$($_.Value.url)`""
			If ($_.Key -eq "googlesource.com") {
				<# CONVERT FROM BASE64 #>
				$ProgressPreference = 'SilentlyContinue'
				$7zaText = Invoke-WebRequest -Uri $_.Value.url
				[IO.File]::WriteAllBytes("7za.exe", [System.Convert]::FromBase64String(($7zaText).Content))
			} Else {
				[System.Net.ServicePointManager]::SecurityProtocol = @("Tls12", "Tls11", "Tls")
				$wc = New-Object System.Net.WebClient
				If ($proxy) {
					$wc.Proxy = $webproxy
				}
				$wc.DownloadFile($_.Value.url, "7za.exe")
			}
			If ($_.Key -eq "7zip.org") {
				Expand-Archive .\7za920.zip 7za.exe
			}
			If ( $(Try { (&Test-Path "7za.exe") } Catch { $False }) ) {
				If ((((Get-FileHash "7za.exe").Hash) -eq $_.Value.hash)) {
					$7z = "7za.exe"
					Write-Msg "Download successful (`"7za.exe`" hash: OK)"
					Return $7z
				} Else {
					Try { Remove-Item "7za.exe" } Catch { $False }
					If ($i -lt $7zUrls.count) {
						Write-Msg "[$i/$($7zUrls.count)] Download failed, file hash did not match. Trying next URL..."
					} Else {
						Write-Msg "Unable to download `"7za.exe`"..."
					}
				}
			}
			$i++
		}
	}
	Return $7z
}

<# FUNC: 7-ZIP #>

Function sevenZip ([string]$action, [string]$7zArgs) {
	$7z = $get7z.Invoke()
	If (!$7z) {
		Write-Msg -o err,tee "7-Zip (`"7z.exe`") not found, exiting..."
		Exit 1
	}
	<# NOTE: (Source) http://www.mobzystems.com/code/7-zip-powershell-module/ #>
	If ($action -eq "listdir") {
		[string[]]$result = &$7z l $7zargs
		[bool]$separatorFound = $False
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
						Write-Msg -o dbg,1 "sevenZip name = $name"
						$dirName = $name
						Return
					}
				}
			}
		}
		Return $dirName
	} ElseIf ($action -eq "extract") {
		Write-Msg -o dbg,1 "`$p = Start-Process -FilePath `"$7z`" -ArgumentList $7zArgs -NoNewWindow -PassThru -Wait"
		$p = Start-Process -FilePath "$7z" -ArgumentList "$7zArgs" -NoNewWindow -PassThru -Wait
		Return $p.ExitCode
	}
}

<# FUNC: SHORTCUT #>

Function createShortcut ([string]$srcExe, [string]$srcExeArgs, [string]$dstPath) {
	If (&Test-Path $srcExe) {
		If ( $(Try { (Test-Path variable:local:dstPath) -And (&Test-Path $dstPath) -And (-Not [string]::IsNullOrWhiteSpace($dstPath)) } Catch { $False }) ) {
			Try { Remove-Item -EA 0 -EA 0 -Force "$dstPath" } Catch { $False }
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
		Write-Msg -o err,tee "$sMsg"
		Return $False
	}
	Return $True
}

<# TODO: Use hash to check virustotal (user needs api key)
Function virusTotal($cdataObj) {
	# URL: $result = Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Uri $cdataObj.virustotal
	# API: $result = Invoke-RestMethod -Method GET 'https://www.virustotal.com/vtapi/v2/file/report?apikey=<apikey>&resource=<hash>'
	# Docs: https://developers.virustotal.com/reference#url-report
	# Example: https://github.com/cbshearer/get-VTFileReport
	If ($result -Match "No engines detected this file") {
		Write-Msg -o dbg,1 "virustotal OK"
	} Else {
		Write-Msg -o dbg,1 "virustotal NOK"
	}
}  #>


<##############>
<# PARSE FEED #>
<##############>

<# FUNC: PARSE CDATA USING 'htmlfile' #>

Function cdataHtml($i, $cdata, $cfg, $items, $cdataObj) {
	Write-Msg -o dbg,1 "cdataHtml `$i=$i"
	$html = New-Object -ComObject "htmlfile"
	$html.IHTMLDocument2_write($cdata)
	$html.getElementsByTagName('li') | ForEach-Object {
		$_name = $_.innerText.split(':')[0].ToLower() -Replace '(\n|\r\n)', '_'
		$_value = $_.innerText.split(':')[1] -Replace '^ ' -Replace ' ?\(virus\?\)'
		#Write-Msg dbg,1 "name=$_name value=$_value"
		$cdataObj | Add-Member -MemberType NoteProperty -Name $_name -Value $_value -Force
		If ($_.getElementsByTagName('a')) {
			$_.getElementsByTagName('a') | ForEach-Object {
				$_name = $_.innerText.replace('virus?', 'virusTotal')
				$_value = $_.href
				#Write-Msg dbg,1 "name=$_name value=$_value - nameProp=$($_.nameProp) hostname=$($_.hostname) - innerText=$($_.innerText.replace('?',''))"
				$cdataObj | Add-Member -MemberType NoteProperty -Name $_name -Value $_value -Force
				If ($_.innerHTML -Match $items[$editor].filemask) {
					$cdataObj | Add-Member -MemberType NoteProperty -Name url -Value $_value -Force
				}
			}
		}
	}

	$cdataObj.titleMatch = $xml.rss.channel.Item[$i].title -Match $items[$editor].title
	$cdataObj.editorMatch = $items[$editor].editor -Match $cdataObj.editor
	$cdataObj.archMatch = $arch -ieq $cdataObj.architecture
	$cdataObj.channelMatch = $channel -ieq $cdataObj.channel
	ForEach ($algo in "md5", "sha1") {
		$_gethash = $cDataObj | Select-Object -ExpandProperty "$($items[$editor].filemask)*$algo" -EA 0 -WA 0
		If ($_gethash) {
			$cdataObj.hash = $_gethash
			$cdataObj.hashAlgo = $algo
		}
	}
	If ($debug -ge 1) {
		$cnt = 0
		If ($cdataObj.titleMatch) {
			$_tMsg = "cdataHtml `$i=$i title=`"$($items[$editor].title)`" -Match xml.rss.channel.Item.title=`"$($xml.rss.channel.Item[$i].title)`"`r`n"
			$cnt++
		}
		If ($cdataObj.editorMatch) {
			$_eMsg = "cdataHtml `$i=$i editor=`"$($items[$editor].editor)`" -Match cdataObj.editor=`"$($cdataObj.editor)`"`r`n"
			$cnt++
		}
		If ($cnt -gt 0 ) {
			Write-Msg -o Yellow ("{0}`r`n{1}{2}{0}" -f ("-" * 80), $_tMsg, $_eMsg)
		}
		If ($debug -ge 9) {
			Write-Msg -o Magenta "DEBUG: `$i=$i outputting 'cdataObj' only, then Exit ..."
			$cdataObj
			Exit
		}
	}
	$cdataObj
}

<# FUNC: PARSE CDATA USING REGEX #>

Function cdataRegex($i, $cdata, $cfg, $items, $cdataObj) {
	Write-Msg -o dbg,2 "cdataRegex `$i=$i"
	<# DEBUG: REGEX MATCHES - Call this scriptblock *after* a '-Match' line by using '&matches'
	$matches = {
		If ($xml.rss.channel.Item[$i].title -Match ".*?(Marmaduke)") {$Matches[1]; $cdataObj.editorMatch = $True}
		Write-Msg -o dbg,2 "Matches[0], [1] = "; % {$Matches[0]}; % {$Matches[1]}}
	} #>
	$cdataObj.titleMatch = $xml.rss.channel.Item[$i].title -Match $items[$editor].title
	$cdataObj.editorMatch = $cdata -Match '(?i)' + $channel + '.*?(Editor: <a href="' + $items[$editor].url + '/">' + $editor + '</a>).*(?i)' + $channel
	$cdataObj.archMatch = $cdata -Match '(?i)' + $channel + '.*?(architecture: ' + $arch + ').*(?i)' + $channel
	$cdataObj.channelMatch = $cdata -Match '(?i)' + $channel + '.*?(Channel: ' + $channel + ')'
	$cdataObj.version = $cdata -Replace ".*(?i)$($channel).*?Version: ([\d.]+).*", '$1'
	$cdataObj.revision = $cdata -Replace ".*(?i)$($channel).*?Revision: (?:<[^>]+>)?(\d{3}|\d{6})<[^>]+>.*", '$1'
	$cdataObj.date = $cdata -Replace ".*(?i)$($channel).*?Date: <abbr title=`"Date format: YYYY-MM-DD`">([\d-]{10})</abbr>.*", '$1'
	$urlReHtml = ".*?(?i)$($channel).*?Download from.*?repository:.*?<li>"
	$urlReLink = "<a href=`"($($items[$editor].repo)(?:v$($cdataObj.version)-r)?$($cdataObj.revision)(?i:-win$($arch.replace('-bit','')))?/"
	#$urlReFile = "$($($items[$editor].filemask).replace('.*',''))($($cdataObj.version).*\.7z)?)"
	$urlReFile = "$($items[$editor].filemask)($($cdataObj.version).*\.7z)?)"
	$cdataObj.url = $cdata -Replace "${urlReHtml}${urlReLink}${urlReFile}`">.*", '$1'
	$_hash = ($_ -Replace ".*?(?i)$($channel).*?<a href=`"$($cdataObj.url)`">$($items[$editor].filemask)</a><br />(?:(sha1|md5): ([0-9a-f]{32}|[0-9a-f]{40})) .*", '$1 $2')
	$cdataObj.hashAlgo, $cdataObj.hash = $_hash.split(' ')
	$cdataObj.virusTotal = $cdata -Replace ".*<a href=`"(https://www.virustotal.com[^ ]+)`" [^ ]+=.*", '$1'

	ForEach ($var in "cdataObj.version", "cdataObj.revision", "cdataObj.date", "cdataObj.url") {
		If ($(Invoke-Expression `$$var) -eq $_) {
			Invoke-Expression ('{0}="{1}"' -f ($var -Replace "^", "$"), $null);
		}
	}

	<# DISABLED: ## Editor exception: Marmaduke ##
	If ( ($($xml.rss.channel.Item[$i].title) -Match "Ungoogled") -And
		 ($cdata -Match '(?i)' + $channel + '.*?(Editor: <a href="' + $items[$editor].url + '/">' + "Marmaduke" + '</a>).*(?i)' + $channel) )
	{
		$cdataObj.titleMatch = $True
		$cdataObj.editorMatch = $True
		$items[$editor].filemask += "$($cdataObj.version).*\.7z"
	} #>

	<# DISABLED: ## Editor exception: ThumbApps ##
	ElseIf ($cdata -Match '(?i)' + $channel + '.*?(Editor: <a href="' + $items[$editor].url + '/">' + "ThumbApps" + '</a>).*(?i)' + $channel) {
		$cdataObj.titleMatch = $True
		$cdataObj.editorMatch = $True
		$items[$editor].filemask += "${version}_Dev_32_64_bit.paf.exe"
		$cdataObj.revision = "thumbapps"
		$cdataObj.url = $cdata -Replace "${urlReHtml}<a href=`"($($items[$editor].repo)$($items[$editor].filemask))`".*", '$1'
		$script:ignHash = 1
		Write-Msg -o tee "There is no hash provided for this installer"
	} #>

	If ($ignVer -eq 1) {
		$cdataObj.revision = '\d{6}'
		$cdataObj.url = $cdata -Replace "${urlReHtml}<a href=`"($($items[$editor].repo)(?:v[\d.]+-r)?$($cdataObj.revision)(?:-win$($arch.replace('-bit','')))?/$($items[$editor].filemask))`".*", '$1'
		$vMsg = "Ignoring version mismatch between RSS feed and filename"
		Write-Msg -o nnl,Yellow "`r`n(!) $vMsg"
		Write-Msg
		Write-Msg -o log "$vMsg"
	}
	If ($debug -ge 1) {
		$cnt = 0
		If ($cdataObj.titleMatch) {
			$_tMsg = "cdataRegex `$i=$i editor=`"$($items[$editor].editor)` -Match xml.rss.channel.Item.title=`"$($xml.rss.channel.Item[$i].title)`"`r`n"
			$cnt++
		}
		If ($cdataObj.editorMatch) {
			$_eMsg = "cdataRegex `$i=$i cdataObj.editorMatch=`"$($cdataObj.editorMatch)`"`r`n"
			$cnt++
		}
		If ($cnt -gt 0 ) {
			Write-Msg -o Yellow ("{0}`r`n{1}{2}{0}" -f ("-" * 80), $_tMsg, $_eMsg)
		}
		If ($debug -ge 8) {
			Exit
		}
	}
	$cdataObj
}

<# FUNC: PARSE RSS FEED #>

Function parseRss ($rssFeed, $cdataMethod) {
	<# PS OBJECT FOR CDATA #>
	$cdataObj = New-Object -Type PSObject -Property @{
		date         = $null
		hash         = $null
		hashAlgo     = $null
		url          = $null
		revision     = $null
		version      = $null
		virusTotal   = $null
		titleMatch   = $False
		editorMatch  = $False
		archMatch    = $False
		channelMatch = $False
		urlMatch     = $False
		hashFmtMatch = $False
	}

	<# MAIN OUTER WHILE LOOP: XML #>
	<# https://paullimblog.wordpress.com/2017/08/08/ps-tip-parsing-html-from-a-local-file-or-a-string #>
	<# TEST: $xml = [xml](Get-Content "C:\TEMP\windows-64-bit") #>
	$xml = [xml](Invoke-WebRequest -UseBasicParsing -TimeoutSec 300 -Uri $rssFeed)

	<# LOOP OVER ITEMS: TITLE, EDITOR #>
	$i = 0
	While ($xml.rss.channel.Item[$i]) {
		Write-Msg -o dbg, 1, Cyan			"`$i=$i xml cdataMethod=$cdataMethod title=$($xml.rss.channel.Item[$i].title)"
		Write-Msg -o dbg, 1				"`$i=$i xml link = $($xml.rss.channel.Item[$i].link)"
		Write-Msg -o dbg, 2, DarkYellow	"`$i=$i xml description = $($xml.rss.channel.Item[$i].description."#cdata-section")"
		<# INNER WHILE LOOP: CDATA HTML #>
		$xml.rss.channel.Item[$i].description."#cdata-section" | ForEach-Object {
			If ($cdataMethod -eq "htmlfile") {
				$cdataObj = cdataHtml $i $_ $cfg $items $cdataObj
			} ElseIf ($cdataMethod -eq "regexp") {
				$cdataObj = cdataRegex $i $_ $cfg $items $cdataObj
			}
			If ($cdataObj.url) {
				$cdataObj.urlMatch = $cdataObj.url -Match ('^https://.*' + '(' + $cdataObj.version + ')?.*' + $cdataObj.revision + '.*' + $items[$editor].filemask)
			} Else {
				Write-Msg -o dbg,1,Yellow "`$i=$i No download url found"
			}
			If ($debug -ge 1) {
				# Write-Msg -o dbg,1 "`$i=$i cdataMethod=$cdataMethod html `$_ = `r`n" $_
				# Write-Msg -o dbg,1 "`$i=$i revision = $($cdataObj.revision) urlcheck =" ('^https://.*' + '(' + $cdataObj.version + ')?.*' + $cdataObj.revision + '.*' + $items[$editor].filemask)
				'cdataObj.editorMatch', 'cdataObj.archMatch', 'cdataObj.channelMatch', 'cdataObj.version', 'channel', `
					'cdataObj.revision', 'cdataObj.date', 'cdataObj.url', 'cdataObj.hashAlgo', 'cdataObj.hash' , 'cdataObj.virusTotal' | ForEach-Object {
					Write-Host "DEBUG: `$i=$i ${_} ="$(Invoke-Expression `$$_)
				}
			}
			<# EDITOR/URL MATCH & HASH CHECK #>
			If ($cdataObj.editorMatch -And $cdataObj.urlMatch) {
				checkHashFmt $cdataObj | Out-Null
				Break
			}
		}
		$i++
		Write-Msg -o dbg, 1
	}
	$cdataObj
}

<# END OF FUNCTIONS #################################>

<# CALL PARSE RSS FUNCTION #>
$errMsg = "Repository format `"$items[$editor].fmt`" or URL `"$($items[$editor].repo)`" not recognized"
If ($items[$editor].fmt -eq "XML") {
	$cdataObj = parseRss "https://${woolyss}/feed/windows-$($arch)" "htmlfile"
	If (!$cdataObj.urlMatch) {
		Write-Msg -o dbg,1,Magenta $(("-" * 80))
		Write-Msg -o dbg,1,Magenta "No matching url found, trying alternative method..."
		Write-Msg -o dbg,1,Magenta $(("-" * 80) + "`r`n")
		$cdataObj = parseRss "https://${woolyss}/feed/windows-$($arch)" "regexp"
	}
	<# PARSING JSON IS DISABLED #>
} ElseIf ($items[$editor].fmt -eq "JSON") {
	If ("$($items[$editor].repo).*" -Match "^https://api.github.com" ) {
		<# REMOVED: parseJsonGh $items[$editor].repo) #>
		Write-Msg -o err "JSON parsing functionality removed, exiting..."
		Exit 1
	} Else {
		Write-Msg -o err,tee "$errMsg, exiting..."
		Exit 1
	}
} Else {
	Write-Msg -o err,tee "$errMsg, exiting..."
	Exit 1
}

If ($debug -ge 1) {
	'cdataObj.titleMatch', 'cdataObj.editorMatch', 'cdataObj.archMatch', 'cdataObj.channelMatch', 'cdataObj.urlMatch', 'cdataObj.hashFmtMatch' | ForEach-Object {
		Write-Host "DEBUG: ${_}(AFTER) = "$(Invoke-Expression `$$_)
	}
	Write-Msg
}

<# SHOW PARSE INFO TO USER #>
$nm = 0
If (!$cdataObj.editorMatch) {
	$nm++; $nmMsg += "  [x] check editor setting: `"$($items[$editor].editor)`""
	If ($cdataObj.editor) {
		$nmMsg += ", found `"$($cdataObj.editor)`""
	}
	$nmMsg += "`r`n"
}
If (!$cdataObj.channelMatch) {
	$nm++; $nmMsg += "  [x] check channel setting: `"$($channel)`""
	If ($cdataObj.channel) {
		$nmMsg += ", found `"$($cdataObj.channel)`""
	}
	$nmMsg += "`r`n"
}
If (!$cdataObj.archMatch) {
	$nm++; $nmMsg += "  [x] check architecture setting: `"$($arch)`""
	If ($cdataObj.architecture) {
		$nmMsg += ", found `"$($cdataObj.arch)`""
	}
	$nmMsg += "`r`n"
}
If (!$cdataObj.urlMatch) {
	$nm++
	$nmMsg += "  [x] unable to find correct url to download install`r`n"
}
If ($nm -gt 0) {
	Write-Msg -o nnl "Found: "
	$cdataObj.PSObject.Properties | Where-Object Name -like *Match* | ForEach-Object {
		$n = ($_.Name -Replace 'Match', '').ToLower()
		Write-Msg -o nnl "${n}["
		If ($_.Value) {
			Write-Msg -o nnl,White "yes"
		} Else {
			Write-Msg -o nnl,DarkRed "no"
		}
		Write-Msg -o nnl "] "
	}
	Write-Msg
	Write-Msg $nmMsg
}
If (!($cdataObj.editorMatch -And $cdataObj.urlMatch)) {
	Write-Msg $noMatchMsg
}

<##############################>
<# DOWNLOAD AND CHECK VERSION #>
<##############################>

$saveAs = "$env:TEMP\$($items[$editor].filemask)"
If ( ($cdataObj.editorMatch -eq 1) -And ($cdataObj.archMatch -eq 1) -And ($cdataObj.channelMatch -eq 1) -And ($cdataObj.urlMatch -eq 1) -And ($cdataObj.hashFmtMatch -eq 1) )	{
	If (($cdataObj.url) -And ($cdataObj.url -NotMatch ".*$curVersion.*")) {
		$ago = ((Get-Date) - ([DateTime]::ParseExact($cdataObj.date, 'yyyy-MM-dd', $null)))
		If ($ago.Days -lt 1) {
			[string]$_agoTxt = ($ago.Hours, "hours")
		} Else {
			[string]$_agoTxt = ($ago.Days, "days")
		}
		Write-Msg -o tee ("New Chromium version `"{0}`" from {1} is available ({2} ago)" -f $cdataObj.version, $cdataObj.date, $_agoTxt)
		If ($debug -ge 1) {
			If (&Test-Path "$saveAs") {
				Write-Msg -o dbg,1 "Would have deleted $saveAs"
			}
			Write-Msg -o dbg,1		   "Would have Downloaded: `"$($cdataObj.url)`""
			Write-Msg -o dbg,1 		   "Using following Path : `"$saveAs`""
			Write-Msg -o dbg,1,Yellow ("{0}`r`n(!) Make sure `"$saveAs`" ALREADY EXISTS to continue debugging`r`n{0}" -f ("-" * 80))
		} Else {
			If (&Test-Path "$saveAs") {
				Remove-Item "$saveAs"
			}
			Write-Msg -o tee "Downloading `"$($cdataObj.url)`""
			Write-Msg -o tee "Saving as: `"$saveAs`""
			[System.Net.ServicePointManager]::SecurityProtocol = @("Tls12", "Tls11", "Tls")
			$wc = New-Object System.Net.WebClient
			If ($proxy) {
				$wc.Proxy = $webproxy
			}
			$wc.DownloadFile($cdataObj.url, "$saveAs")
		}
	} Else {
		$_lMsg = "Latest Chromium version already installed"
		Write-Msg -o nnl		"["
		Write-Msg -o nnl,Green	"OK"
		Write-Msg -o nnl		"] $_lMsg"
		Write-Msg "`r`n"
		Write-Msg -o log "$_lMsg"
		Exit 0
	}
} Else {
	Write-Msg "$noMatchMsg"
	Write-Msg -o tee "No matching Chromium versions found, exiting..."
	Write-Msg
	Exit 0
}

<###################################>
<# VERIFY HASH, INSTALL OR EXTRACT #>
<###################################>

$fileHash = (Get-FileHash -Algorithm $cdataObj.hashAlgo "$saveAs").Hash
If ($ignHash -eq 1) {
	$cdataObj.hash = $fileHash
	Write-Msg -o tee "Ignoring hash, using hash from downloaded installer: `"$($cdataObj.hash)`""
}
If (-Not ($cdataObj.hashAlgo) -Or ([string]::IsNullOrWhiteSpace($cdataObj.hashAlgo))) {
	Write-Msg -o err,tee "Hash Algorithm is missing, exiting..."
	Exit 1
}
If (-Not ($cdataObj.hash) -Or ([string]::IsNullOrWhiteSpace($cdataObj.hash))) {
	Write-Msg -o err,tee "Hash is missing, exiting..."
	Exit 1
}
If (( $(Try { (Test-Path variable:local:fileHash) -And (-Not [string]::IsNullOrWhiteSpace($fileHash)) -And ($fileHash -eq $cdataObj.hash) } Catch { $False }) )) {
	$_hMsg = "$($cdataObj.hashAlgo.ToUpper()) hash matches `"$($cdataObj.hash)`""
	If ($saveAs -Match ".*\.exe$") {
		$fileFmt = "exe"
		Write-Msg -o tee "$_hMsg"
		Write-Msg -o tee "Executing `"$($items[$editor].filemask)`""
	} ElseIf ($saveAs -Match ".*\.(7z|zip)$") {
		$fileFmt = "arc"
		$extrTo = ""
		$i = 0
		ForEach ($extrTo in $arcInstDirs) {
			If (($extrTo -ne "") -And (Test-Path -pathType Container -EA 0 -WA 0 $extrTo)) {
				$i++
				Break
			}
		}
		If ($i -gt 0) {
			Write-Msg -o tee "Extracting `"$($items[$editor].filemask)`" to `"$extrTo`""
		} Else {
			Write-Msg -o err,tee "Could not find dir to extract to, exiting..."
			Exit 1
		}
	}

	<# TEST: If ($fakeVer -eq 1) { $saveAs += "-FakeVer" } #>

	<# write [OK] msg in green and optional $_dMsg #>
	$_doneMsg = {
		Write-Msg -o nnl       "["
		Write-Msg -o nnl,Green "OK"
		Write-Msg -o nnl       "] Done. "
		Write-Msg -o Yellow "${_dMsg}."
		Write-Msg -o log "Done. $_dMsg"
	}

	If ($fileFmt -eq "exe") {
		$exeArgs = "--do-not-launch-chrome"
		Write-Msg -o dbg,1 "`$p = Start-Process -FilePath `"$saveAs`" -ArgumentList $exeArgs -Wait -NoNewWindow -PassThru"
		$p = (Start-Process -FilePath "$saveAs" -ArgumentList $exeArgs -Wait -NoNewWindow -PassThru)
		If ($p.ExitCode -eq 0) {
			$_dMsg = "New Chromium version will be used on next app (re)start"
			& $_doneMsg
		} Else {
			Write-Msg -o err,tee,nnl "after executing `"$($items[$editor].filemask)`""
			If ($p.ExitCode) {
				Write-Msg -o err,tee ":" $p.ExitCode
			}
		}
		If (&Test-Path $installLog) {
			Write-Msg -o log,Red "Installer logfile: $installLog"
		}
	} ElseIf ($fileFmt -eq "arc") {
		If ($appDir -eq 1) {
			$retArcDir = "$($items[$editor].editor)"
			If (&Test-Path -pathType Container "${extrTo}\${retArcdir}") {
				Remove-Item -EA 0 -WA 0 -Recurse -Force "${extrTo}\${retArcdir}"
			}
		} Else {
			$retArcDir = &sevenZip "listdir" "$saveAs"
		}
		Write-Msg -o dbg,1 "extrTo\retArcdir = ${extrTo}\${retArcdir}"
		If (-Not (&Test-Path "${extrTo}\${retArcdir}")) {
			If ($retArcDir) {
				$retExtract = &sevenZip "extract" "x $saveAs -o${extrTo} -y"
				If ($retExtract -eq 0) {
					$_dMsg = "New Chromium version extracted to `"${extrTo}\${retArcdir}`""
					$lnkTarget = "${extrTo}\${retArcdir}\chrome.exe"
					<# $lnkName = "$env:USERPROFILE\Desktop\Chromium $version.lnk" #>
					$lnkName = "$env:USERPROFILE\Desktop\Chromium.lnk"
					Write-Msg -o dbg,1 "lnkTarget = `"$lnkTarget`" linkName = `"$lnkName`""
					$retShortcut = &createShortcut "$lnkTarget" "$lnkExecArgs" "$lnkName"
					If (-Not $retShortcut) {
						Write-Msg -o err,tee "Could not create shortcut on Desktop"
					} Else {
						$_dMsg += " and shortcut created on Desktop"
					}
					& $doneMsg
				} Else {
					Write-Msg -o err,tee "Could not extract `"$saveAs`", exiting..."
					Exit 1
				}
			} Else {
				Write-Msg -o err,tee "No directory to extract found inside archive `"$saveAs`", exiting..."
				Exit 1
			}
		} Else {
			Write-Msg -o err,tee "Directory `"${extrTo}\${retArcDir}`" already exists, exiting..."
			Exit 1
		}
	}
} Else {
	Write-Msg -o err,tee "$($cdataObj.hashAlgo.ToUpper()) hash does NOT match: `"$($cdataObj.hash.ToUpper())`". Exiting..."
	Exit 1
}
Write-Msg
