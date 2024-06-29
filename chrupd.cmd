<# :
@echo off & SETLOCAL & SET "_PS=powershell.exe -NoLogo -NoProfile" & SET "_ARGS=\"%~dp0" %*"
%_PS% "&(Invoke-Command {[ScriptBlock]::Create('$Args=@(&{$Args} %_ARGS%);'+((Get-Content \"%~f0\") -Join [char]10))})"
ENDLOCAL & dir "%~f0.tmp" >nul 2>&1 && move /Y "%~f0" "%~f0.bak" >nul 2>&1 && move /Y "%~f0.tmp" "%~f0" >nul 2>&1 & GOTO :EOF
#>

<#
.SYNOPSIS
   -------------------------------------------------------------------------
    20240327 MK: Simple Chromium Updater (chrupd.cmd)
   -------------------------------------------------------------------------

.DESCRIPTION
	Installs latest available Chromium version
	Checks RSS feed from "chromium.woolyss.com" and GitHub API
	
	Downloads, verifies sha/md5 hash and runs installer:
	default name: "Hibbiki", channel "stable", arch "64bit"
	set options using cli args or under CONFIGURATION in script

.EXAMPLE
    PS> .\chrupd.ps1 -name Marmaduke -arch 64bit -channel stable [-crTask]
#>

<# ------------------------------------------------------------------------- #>
<# CONFIGURATION:                                                            #>
<# ------------------------------------------------------------------------- #>
<# Make sure the combination of name and channel is correct.                 #>
<# See "chrupd.cmd -h" or README.md for more options and details.            #>
<# ------------------------------------------------------------------------- #>
$cfg = @{
    name     = "Hibbiki";       <# Name of Chromium release (fka "editor")   #>
    channel  = "stable";        <# dev, stable                               #>
    arch     = "64bit";         <# Architecture: 32bit or 64bit (default)    #>
    log      = $true            <# enable or disable logging <$true|$false>  #>
    cAutoUp  = $true            <# auto update this script <$true|$false>    #>
};
<# END OF CONFIGURATION ---------------------------------------------------- #>


<####################>
<# SCRIPT VARIABLES #>
<####################>

<# Set-StrictMode -Version 3.0 #>

<# the vars defined below can be changed if you want, be careful as they can break the script #>

<# VAR: define registry keys and paths with chromium version #>
[hashtable]$versionRegKeys = @{
	User = [ordered]@{
		"HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Chromium" = "Version"
		"HKCU:\SOFTWARE\Chromium" = "pv"
	};
	System = [ordered]@{
		"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Chromium" = "Version"
		"HKLM:\SOFTWARE\Chromium" = "pv"
		"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Chromium" = "Version"
		"HKLM:\SOFTWARE\WOW6432Node\Chromium" = "pv"
	}
}
[hashtable]$versionPaths = @{
	User = @( "${env:LocalAppData}\Chromium\Application" );
	System = @( "${env:ProgramFiles}\Chromium\Application", "${env:ProgramFiles(x86)}\Chromium\Application" ) <# 64bit, 32bit #>
}

<# VAR: define releases #>
<# items[$name] = @{ author, source, url, repository, filemask [alias, no_hash, no_arch, disabled] } #>
[hashtable]$items = @{
	"Official" = @{
		author   = "The Chromium Authors";
		fmt      = "XML";
		url      = "https://www.chromium.org";
		repo     = "https://storage.googleapis.com/chromium-browser-snapshots/Win_x64/";
		filemask = "mini_installer.exe";
		alias    = "Chromium"
	};
	"Hibbiki" =	@{
		author   = "Hibbiki";
		fmt      = "XML";
		url      = "https://chromium.woolyss.com";
		repo     = "https://github.com/Hibbiki/chromium-win64/releases/download/";
		filemask = "mini_installer.sync.exe"
	};
	"Marmaduke" = @{
		author   = "Marmaduke";
		fmt      = "XML";
		url      = "https://chromium.woolyss.com";
		repo     = "https://github.com/macchrome/winchrome/releases/download/";
		filemask = "mini_installer.exe"
	};
	"Ungoogled-Marmaduke" = @{
		author   = "Marmaduke";
		fmt      = "XML";
		url      = "https://chromium.woolyss.com";
		repo     = "https://github.com/macchrome/winchrome/releases/download/";
		<# filemask = "ungoogled-chromium-" #>
		filemask = "ungoogled_mini_installer.exe"
		alias    = @( "Ungoogled-Marmaduke", "Ungoogled" )
	};
	"Ungoogled-Portable" = @{
		author   = "Portapps";
		fmt      = "XML";
		url      = "https://chromium.woolyss.com";
		repo     = "https://github.com/portapps/ungoogled-chromium-portable/releases/";
		filemask = "ungoogled-chromium-"
		alias    = "Ungoogled-Portapps"
	};
	"Ungoogled-Eloston" = @{
		author   = "Eloston";
		fmt      = "JSON";
		url      = "https://github.com/ungoogled-software/ungoogled-chromium-windows";
		repo     = "https://api.github.com/repos/ungoogled-software/ungoogled-chromium-windows/releases";
		filemask = "ungoogled-chromium_"
		alias    = @( "Eloston-Ungoogled", "Eloston" )
	};
	"justclueless" = @{
		author   = "justclueless";
		fmt      = "JSON";
		url      = "https://github.com/justclueless/chromium-win64";
		repo     = "https://api.github.com/repos/justclueless/chromium-win64/releases";
		filemask = "mini_installer.exe"
	};
	"RobRich" = @{
		author   = "RobRich999";
		fmt      = "JSON";
		url      = "https://github.com/RobRich999/Chromium_Clang";
		repo     = "https://api.github.com/repos/RobRich999/Chromium_Clang/releases";
		filemask = "mini_installer.exe";
		alias    = "RobRich999";
	};
	<# DISABLED: not added to woolyss' api yet
	"justclueless" = @{
		author   = "justclueless";
		fmt      = "XML";
		url      = "https://chromium.woolyss.com";
		repo     = "https://github.com/justclueless/chromium/releases/";
		filemask = "mini_installer.exe"
	};  #>
	<# DISABLED: discontinued
	"RobRich" =	@{
		author   = "RobRich";
		fmt      = "XML";
		url      = "https://chromium.woolyss.com";
		repo     = "https://github.com/RobRich999/Chromium_Clang/releases/download/";
		filemask = "mini_installer.exe"
	};  #>
	<# DISABLED: not updated anymore
	"ThumbApps" = @{
		author = "ThumbApps";
		url = "http://www.thumbapps.org";
		fmt = "XML";
		repo = "https://netix.dl.sourceforge.net/project/thumbapps/Internet/Chromium/";
		filemask = "ChromiumPortable_"
	};  #>
	<# DISABLED: OLD Chromium-ungoogled from GH, before Woolyss added it
	"Chromium-ungoogled" = @{
		author = "Marmaduke";
		url = "https://github.com/macchrome/winchrome";
		fmt = "JSON";
		repo = "https://api.github.com/repos/macchrome/winchrome/releases";
		filemask = "ungoogled-chromium-";
	};  #>
}

<# VAR: define os #>
<# Windows @(majorVer, minorVer, build, osType[1=ws,3=server], tsMode) #>
[hashtable]$osObj = @{
	winVer = [ordered]@{
		"Windows 11"             = @(10, 0, 22000, 1, 1);
		"Windows 10"             = @(10, 0, 00000, 1, 1);
		"Windows 8.1"            = @( 6, 3, 00000, 1, 1);
		"Windows 8"              = @( 6, 2, 00000, 1, 1);
		"Windows 7"              = @( 6, 1, 00000, 1, 2);
		"Windows Vista"          = @( 6, 0, 00000, 1, 2);
		"Windows XP 64bit"       = @( 5, 2, 00000, 1, 3);
		"Windows XP"             = @( 5, 1, 00000, 1, 3);
		"Windows Server 2022"    = @(10, 0, 20285, 3, 1);
		"Windows Server 2019"    = @(10, 0, 17134, 3, 1);
		"Windows Server 2016"    = @(10, 0, 00000, 3, 1);
		"Windows Server 2012 R2" = @( 6, 3, 00000, 3, 1);
		"Windows Server 2012"    = @( 6, 2, 00000, 3, 1);
		"Windows Server 2008 R2" = @( 6, 1, 00000, 3, 2);
		"Windows Server 2008"    = @( 6, 0, 00000, 3, 2);
		"Windows Server 2003"    = @( 5, 2, 00000, 3, 3);
	}
	osTypeName = @{
		1 = "Workstation";
		2 = "DC";
		3 = "Server";
	}
	taskModeName = @{
		0 = "Auto";
		1 = "Normal";
		2 = "Legacy";
		3 = "Schtasks Command"
	}
}

<# VAR: define 7z locations #>
[hashtable]$7zConfig = @{
	"Paths" = (
		"7z.exe",
		"7za.exe",
		"$env:ProgramFiles\7-Zip\7z.exe",
		"$env:ProgramData\chocolatey\tools\7z.exe",
		"$env:ProgramData\chocolatey\bin\7z.exe"
	);
	"Urls" = @{
		"7zip.org"         = @{ hash = "C136B1467D669A725478A6110EBAAAB3CB88A3D389DFA688E06173C066B76FCF"; url = "https://www.7-zip.org/a/7za920.zip" };
		"github-chromium"  = @{ hash = "EA308C76A2F927B160A143D94072B0DCE232E04B751F0C6432A94E05164E716D"; url = "https://github.com/chromium/chromium/raw/master/third_party/lzma_sdk/Executable/7za.exe" };
		"googlesource.com" = @{ hash = "EA308C76A2F927B160A143D94072B0DCE232E04B751F0C6432A94E05164E716D"; url = "https://chromium.googlesource.com/chromium/src.git/+/0a6a88b4a4c747c3d95c41fb3f9fc5cc726d04ba/third_party/lzma_sdk/Executable/7za.exe?format=TEXT" };
		"chocolatey.org"   = @{ hash = "31FD52F8996986623CF52C3B4D0F7AC74A9DEC63FC16C902CEF673EED550C435"; url = "https://chocolatey.org/7za.exe" };
	}
}

<# VAR: define paths to extact and install archives #>
[object]$archiveInstallPaths = @(
	"$env:LocalAppData\Chromium\Application",
	"$([Environment]::GetFolderPath('Desktop'))",
	"$env:USERPROFILE\Desktop",
	"$env:TEMP"
)

<# VAR: define task user msgs #>
[hashtable]$taskMsg = @{
	descr    = "Download and install latest Chromium version";
	create   = "Creating Daily Task `"$scriptName`" in Task Scheduler...";
	failed   = "Creating Scheduled Task failed.";
	problem  = "Something went wrong...";
	exists   = "Scheduled Task already exists.";
	notfound = "Scheduled Task not found.";
	remove   = "Removing Daily Task `"$scriptName`" from Task Scheduler...";
	rmfailed = "Could not remove Task: $scriptName.";
	notask   = "Scheduled Task already removed.";
	manual   = "Run `"$scriptCmd -manTask`" for manual instructions";
	export   = "Run `"$scriptCmd -xmlTask`" to export a Task XML File"
}

[string]$noMatchMsg = @"
Unable to find new version. If settings are correct, it's possible
the script needs to be updated or there could be an issue with
the RSS feed from `"chromium.woolyss.com`" or the GitHub REST API.`r`n
"@

<# check if we're dot sourced #>
[boolean]$dotSourced = $false
if ($MyInvocation.InvocationName -eq '.' -or $MyInvocation.Line -eq '') {
	$dotSourced = $true
}
<# copy args so we keep original array unchanged #>
[object]$_Args = $Args
[string]$scriptDir = $_Args[0]

<# XXX: Order matters for 'script functions'; keep them on top, before the rest of script #>

<# SCRIPT FUNC: test var #>
function script:Test-Variable($v) {
	try {
		$varExists = (Test-Path variable:$v)
		$varIsEmpty = [string]::IsNullOrWhiteSpace($(Get-Variable "$v" -Scope 1 -ValueOnly -EA 0 -WA 0))
	} catch {
		$false
	}
	if ($varExists -and (-not $varIsEmpty)) {
		return $true
	}
	return $false
}

<# VAR: set script dir, cmd and log #>
<# XXX: EA|WA = ErrorAction|WarningAction: 0=SilentlyContinue 1=Stop 2=Continue 3=Inquire 4=Ignore 5=Suspend  #>
if ( (Test-Variable "scriptDir") -and (&Test-Path -EA 4 -WA 4 $scriptDir)) {
	$rm = $_Args[0]
	$_Args = $_Args | Where-Object { $_ -ne $rm }
} else {
	$scriptDir = ($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.\'))
}
[string]$logFile = $scriptDir + "\chrupd.log"
[string]$scriptName = "Simple Chromium Updater"
[string]$scriptCmd = "chrupd.cmd"
[string]$installLog = "$env:TEMP\chromium_installer.log"
if ($PSCommandPath) {
	$scriptDir = Split-Path -parent $PSCommandPath
	$scriptCmd = (Get-Item $PSCommandPath).Name
} elseif ($MyInvocation.MyCommand.Name) {
	$scriptDir = Split-Path -parent $MyInvocation.MyCommand.Path
	$scriptCmd = $MyInvocation.MyCommand.Name
}

<# VAR: define default values #>
[int]$scheduler = 0
[int]$list = 0
<# debug #>
[int]$debug = 0
[int]$fakeVer = 0
[int]$force = 0
[int]$ignVer = 0
[int]$script:ignHash = 0
<# tasks #>
[int]$tsMode = [int]$crTask = [int]$rmTask = [int]$shTask = [int]$xmlTask = [int]$manTask = [int]$noVbs = [int]$confirm = 0
<# advanced options #>
[string]$proxy = ""
[string]$linkArgs = ""
[string]$vtApikey = ""
[int]$appDir = 0
[int]$sysLvl = 0
[int]$cAutoUp = 1
[bool]$logFileOk = $false
[string]$chrInstall = "User"
[int]$ignDotSrc = 0
if ($dotSourced) {
	[int]$cAutoUp = 0
}

<# SET: chrupd script version #>
[string]$curScriptDate = (Select-String -EA 0 -WA 0 -Pattern " 20[2-3]\d{5} " "${scriptDir}\${scriptCmd}") -replace '.* (20[2-3]\d{5}) .*', '$1'
if (-not $curScriptDate) {
	$curScriptDate = "19700101"
}

<# CHECK: logfile #>
if ($cfg.log) {
	if ((Test-Variable "logFile") -and (&Test-Path $logFile)) {
		try {
			[IO.File]::OpenWrite($logFile).close()
			$logFileOk = $true
		} catch { $null }
	}
}

<########>
<# HELP #>
<########>

if ($_Args -iMatch "[-/?]h") {
	$_Header = ("{0} ({1}:{2})" -f "$scriptName", "$scriptCmd", "$curScriptDate")
	Write-Host "`r`n$_Header"
	Write-Host ("-" * $_Header.Length)"`r`n"
	Write-Host "Installs latest available Chromium version"
	Write-Host "Checks RSS feed from `"chromium.woolyss.com`" and GitHub API", "`r`n"
	Write-Host "USAGE: $scriptCmd -[name|arch|channel|force] or -[list|crTask|shTask]", "`r`n"
	Write-Host "`t", "-name    option must be set to a release name:   (default=Hibbiki)"
	Write-Host "`t`t", " <Official|Hibbiki|Marmaduke|Ungoogled|justclueless|Eloston|RobRich>"
	Write-Host "`t", "-channel can be set to [stable|dev] (default=stable)"
	Write-Host "`t", "-arch    can be set to [64bit|32bit] (default=64bit)", "`r`n"
	Write-Host "`t", "-list    show available releases and exit"
	Write-Host "`t", "-crTask  create a daily scheduled task and exit"
	Write-Host "`t", "-shTask  show scheduled task details and exit"
	Write-Host "`t", "-force   always (re)install, even if latest version is installed", "`r`n"
	Write-Host "EXAMPLE: `".\$scriptCmd -name Marmaduke -arch 64bit -channel stable [-crTask]`"", "`r`n"
	Write-Host "NOTES:   Options `"name`" and `"channel`" need an argument (CasE Sensive)"
	Write-Host "`t", "Try '$scriptCmd -advhelp' for `"advanced`" options", "`r`n"
	exit 0
}

<# ADVANCED HELP #>
if ($_Args -iMatch "[-/?]ad?v?he?l?p?") {
	$_Header = ("{0}: Advanced Options" -f "$scriptName")
	Write-Host "`r`n$_Header"
	Write-Host ("-" * $_Header.Length)"`r`n"
	Write-Host "USAGE: $scriptCmd -[tsMode|rmTask|noVbs|confirm|proxy|cAutoUp|cUpdate]"
	Write-Host "`t`t", " -[appDir|linkArgs|sysLvl|ignVer]", "`r`n"
	Write-Host "`t", "-tsMode    task scheduler mode, set option to <1|2|3> (default=auto)"
	Write-Host "`t", "           where 1=normal:win8+ 2=legacy:win7 3=cmd:schtasks"
	Write-Host "`t", "-rmTask    remove scheduled task and exit"
	Write-Host "`t", "-noVbs     do not use vbs wrapper to hide window when creating task"
	Write-Host "`t", "-confirm   answer 'Y' on prompt about removing scheduled task"
	Write-Host "`t", "-proxy     use a http proxy server, set option to <uri>", "`r`n"
	Write-Host "`t", "-cAutoUp   auto update this script, set option to <0|1> (default=1)"
	Write-Host "`t", "-cUpdate   manually update this script to latest version and exit", "`r`n"
	Write-Host "`t", "-appDir    extract archives to %AppData%\Chromium\Application\`$name"
	Write-Host "`t", "-linkArgs  option sets chrome.exe <arguments> in Chromium shortcut"
	Write-Host "`t", "-sysLvl    system-level, install for all users on machine"
	Write-Host "`t", "-ignVer    ignore version mismatch between rss feed and filename", "`r`n"
	exit 0
}

<####################>
<# HANDLE ARGUMENTS #>
<####################>

<# handle only 'flags' - no options that have args #>
foreach ($a in $_Args) {
	$flags = "[-/](force|fakeVer|list|rss|crTask|rmTask|shTask|xmlTask|manTask|noVbs|confirm|scheduler|ignHash|cUpdate|appDir|sysLvl|ignVer)"
	if ($match = $(Select-String -CaseSensitive -Pattern $flags -AllMatches -InputObject $a)) {
		Invoke-Expression ('{0}="{1}"' -f ($match -replace "^-", "$"), 1);
		$_Args = ($_Args) | Where-Object { $_ -ne $match }
	}
}
<# handle options with args #>
if (($_Args.length % 2) -eq 0) {
	$i = 0
	While ($_Args -Is [Object[]] -and $i -lt $_Args.length) {
		<# OLD: $i = 0; While ($i -lt $_Args.length) { #>
		if ((($_Args[$i] -match "^-debug") -and ($_Args[($i + 1)] -match "^\d")) -or (($_Args[$i] -match "^-") -and ($_Args[($i + 1)] -match "^[\w\.]"))) {
			Invoke-Expression ('{0}="{1}"' -f ($_Args[$i] -replace "^-", "$"), ($_Args[++$i] | Out-String).Trim());
		}
		$i++
	}
} else {
	Write-Host -ForegroundColor Red "Invalid option(s) specified (they're CasE Sensive)"
	Write-Host -ForegroundColor Red "Try `"$scriptCmd -h`" for help, exiting..."
	exit 1
}

<# SET: inline script config, overwrite any args from cli #>

<# editor arg (legacy) #>
if (!$name -and $editor) {
	$name = $editor
}
if (!$name -and $cfg.name) {
	$name = $cfg.name
}
<# editor cfg (legacy) #>
if ((!$name -and !$cfg.name) -and $cfg.editor) {
	$name = $cfg.editor
}
if (!$channel -and $cfg.channel) {
	$channel = $cfg.channel
}
if (!$arch -and $cfg.arch) {
	$arch = $cfg.arch
}
if (!$proxy -and $cfg.proxy) {
	$proxy = $cfg.proxy
}
if (!$cAutoUp -and ($cfg.cAutoUp -eq $true) -and (!$dotSourced)) {
	$cAutoUp = 1
}
if ($cfg.linkArgs) {
	$srcExeArgs = $cfg.linkArgs
}
if ($linkArgs) {
	$srcExeArgs = $linkArgs
}
if ($ignhash) {
	$script:ignHash = 1
}
if (!$vtApiKey -and $cfg.vtApiKey) {
	$vtApiKey = $cfg.vtApiKey
}
if ($cfg.sysLvl) {
	$sysLvl =  $cfg.sysLvl
}
if ($proxy) {
	$PSDefaultParameterValues.Add("Invoke-WebRequest:Proxy", "$proxy")
	$webproxy = New-Object System.Net.WebProxy
	$webproxy.Address = $proxy
}
<# CHECK: alias match, overrides var #>
if (Test-Variable "name") {
	$items.GetEnumerator() | Where-Object { !$_.Value.disabled  } | ForEach-Object {
		if ($name -in $_.Value.alias) {
			$name = $_.Key
		}
	}
}
@{ "32bit|32|x86" = "32-bit"; "64bit|64|x64" = "64-bit"; }.GetEnumerator() | ForEach-Object {
	if ($_.Key -match $arch) {
		$arch = $_.Value
	}
}

<# SET: Chromium version from registry or path #>
if ($sysLvl -eq 1) {
	$chrInstall = "System"
}
$versionRegKeys[$chrInstall].GetEnumerator() | ForEach-Object {
	if (-not $curVersion) {
		$curVersion = (Get-ItemProperty -EA 0 -WA 0 $_.name).$($_.value)
	}
}
if (-not (Test-Variable "curVersion")) {
	$versionPaths[$chrInstall] | ForEach-Object {
		if ((-not $installPath) -and (&Test-Path $_)) {
			$installPath = $_
		}
	}
	$curVersion = (Get-ChildItem $installPath -EA 0 -WA 0 | Where-Object { $_.Name -match "\d\d.\d.\d{4}\.\d{1,3}" } ).Name |
					Sort-Object | Select-Object -Last 1
}


<# SCRIPT FUNC: msg #>
function Write-Msg {
	<#
		.SYNOPSIS
			Helper function to format and output (debug) messages
		.NOTES
			Place on top of main script, *before* first msg call
		.PARAMETER options
				dbg                "DEBUG: some msg"
				dbg, 1              if ($debug -ge 4) { "DEBUG:level 1" }
				err                "ERROR: some msg"    (Red)
				wrn                "WARNING: some msg"  (Yellow)
				nnl                NoNewLine
				log                log msg to file
				tee                log msg to file AND stdout
				fgColor            e.g. Blue
				fgColor,bgColor    e.g. White,DarkGray
		.DESCRIPTION
			Write-Msg [-o dbg,(int)lvl,err,wrn,log,nnl,tee,fgColor|fgColor,bgColor] "String"
		.EXAMPLE
			Write-Msg -o dbg, 1, Magenta, tee "some debugging text"
	#>
	[CmdletBinding()]
	param (
		[Alias("o")]
		[ValidateScript({
				if ("$_" -match "dbg|warn|err|nnl|log|tee|out|^[0-9]$|^(?-i:[A-Z][a-zA-Z]{2,})") {
					$true
				} else {
					Throw "Invalid value is: `"$_`""
				}
			})]
		$options,
		[Parameter(Position = 1, ValueFromRemainingArguments = $true)]
		[string]$msg
	)
	[bool]$dbg = [bool]$log = [bool]$tee = $false
	[int]$lvl = 0
	$msgParams = @{}
	$cnt = 0
	foreach ($opt in $options) {
		switch -regex ($opt) {
			'dbg' { $pf = "DEBUG: "; $dbg = $true; }
			'warn'	{ $pf = "WARNING: "; $msgParams += @{ForegroundColor = "Yellow" } }
			'err'	{ $pf = "ERROR: "; $msgParams += @{ForegroundColor = "Red" } }
			'nnl'	{ $msgParams += @{NoNewLine = $true} }
			'log'	{ $log = $true }
			'tee'	{ $tee = $true }
			'out'	{ $out = $true }
			'^[0-9]$'	{ $lvl = $($matches[0]) }
			'^(?-i:[A-Z][a-zA-Z]{2,})' {
				if ($cnt -ge 1) {
					$msgParams += @{BackgroundColor = $($matches[0]) }
				} else {
					$msgParams += @{ForegroundColor = $($matches[0]) }
				}
				$cnt++
			}
		}
	}
	if (!$log -and ((!$dbg) -or (($dbg) -and ($debug -ge $lvl)))) {
		if ($msg.Split()[0] -eq "System.Object[]") {
			$pf = "DEBUG[invalid_opts]: "
			$s = $msg.Split()
			$msg = $s[1..$s.Length]
		}
		if ($out) {
			Write-Output @msgParams ("{0}$msg" -f $pf)
		} else {
			Write-Host @msgParams ("{0}$msg" -f $pf)
		}
	}
	if ($logFileOk -and ($log -or $tee)) {
		Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " $msg")
	}
}

Write-Msg -o dbg, 1 "`$chrInstall=`"$chrInstall`""

<# SCRIPT FUNC: windows version #>
function Get-WinVer {
	<#
		.SYNOPSIS
			Get Windows Version and supported Task Scheduler Mode
		.NOTES
			Place in main script *before* using 'tsMode' variable
	#>
	param(
		[hashtable]$osInfo,
		[int]$tsModeNum
	)

	[bool]$osFound = $false
	[version]$osVersion = [System.Environment]::OSVersion.Version
	[int]$osProdType = (Get-CIMInstance Win32_OperatingSystem).ProductType
	[string]$osFullName = "Unknown Windows Version"

	<# DEBUG: TEST WINVER
	if ($debug -ge 3) {
			[version]$osVersion = "6.1"; $osProdType = 3
			[version]$osVersion = '10.0.22621.0'; $osProdType = 3
			[version]$osVersion = '10.0.19042'; $osProdType = 3
			[version]$osVersion = '10.0.20285'; $osProdType = 3
	#>

	$osInfo.winVer.GetEnumerator() | ForEach-Object {
		if (-not $osFound) {
			$compareVersion = ([version]("{0}.{1}" -f $osVersion.Major, $osVersion.Minor).ToString()).CompareTo(([version]("{0}.{1}" -f $_.Value[0..1])))
			if ($compareVersion -eq 0 -and ($osVersion.Build -ge $_.Value[2]) -and ($osProdType -eq $_.Value[3])) {
				$osFound = $true
				$osFullName = ("`"{0}`" ({1}.{2}.{3}, {4})" -f $_.Key, $osVersion.Major, $osVersion.Minor, $osVersion.Build, $osInfo.osTypeName[$osProdType])
				$osTsModeNum = $_.Value[4]
				return $osFound, $osFullName, $osTsModeNum
			}
		}
	} | Out-Null
	if ($tsModeNum -notmatch '^[1-3]$') {
		$tsModeNum = if ($osFound) { $osTsModeNum } else { 3 }
	}
	return @{
		osFullName = $osFullName
		tsMode = $tsModeNum
		tsModeName = $osObj.taskModeName.$tsModeNum
	}
}

[hashtable]$winVerResult = Get-WinVer -osInfo $osObj -tsModeNum $tsMode
$tsMode =  $winVerResult.tsMode

<# OPTION: 'list' shows version, name, rss and exits #>
if ($list -eq 1) {
	Write-Msg
	Write-Msg -o nnl "Currently installed Chromium version: "
	Write-Msg $curVersion
	Write-Msg "`r`n"
	Write-Msg "Available releases:"
	$items.GetEnumerator() | Where-Object Value | `
		Format-Table @{l = 'Name'; e = { $_.Key } }, `
					 @{l = 'Website'; e = { $_.Value.url } }, `
					 @{l = 'Repository'; e = { $_.Value.repo } }, `
					 @{l = 'Filemask'; e = { $_.Value.filemask } }
	<# Write-Msg "Available from Woolyss RSS Feed:"
	   $xml = [xml](Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Uri "https://chromium.woolyss.com/feed/windows-$($arch)")
	   $xml.rss.channel.Item | Select-Object @{N = 'Title'; E = 'title' }, @{N = 'Link'; E = 'link' } | Out-String  #>
	exit 0
}

<# CHECK: mandatory and user args #>
if (-not ($items.Keys -ceq $name)) {
	Write-Msg -o err "Name setting incorrect `"$name`" (CasE Sensive). Exiting ..."
	exit 1
} else {
	$items.GetEnumerator() | ForEach-Object {
		if ($_.Name -ceq $name) {
			if ($items[$_.Name].fmt -cnotmatch"^(XML|JSON)$") {
				Write-Msg -o err "Invalid format `"${items[$_.Name].fmt}`", must be `"XML`" or `"JSON`". Exiting ..."
				exit 1
			}
		}
	}
}
if ($arch -cnotmatch"^(32-bit|64-bit)$") {
	$arch = "64-bit"
	Write-Msg "Using default architecture (64-bit)"
}
if ($channel -cnotmatch"^(stable|dev)$") {
	$channel = "stable"
	Write-Msg "Using default channel (`"stable`")"
}
if ($cAutoUp -notmatch "^(0|1)$") {
	Write-Msg -o warn, tee "Invalid AutoUpdate setting `"$cAutoUp`", must be 0 or 1"
}

<# SCRIPT FUNC: update #>
function Split-Script ($content) {
	<#
		.SYNOPSIS
			Splits header and config from script content
		.INPUTS
			$content   Array of strings/lines (do not use filename)
		.OUTPUTS
			$result    Object or Boolean $false
	#>
	[int]$lnCfgStart = ($content | Select-String -Pattern "<# CONFIGURATION:? \s+ #>").LineNumber
	[int]$lnCfgEnd = ($content | Select-String -Pattern "<# END OF CONFIGURATION ?[#-]+ ?#>").LineNumber
	[hashtable]$result = @{}
	if (($lnCfgStart -gt 1) -and ($lnCfgEnd -gt 1)) {
		[object]$result.head = $content | Select-Object -Index (0..(${lnCfgStart} - 2))
		[object]$result.config = $content | Select-Object -Index ((${lnCfgStart} - 1)..$(${lnCfgEnd} - 1))
		[int]$lineCount = ($content).Count
		[string]$lastLine = $content | Select-Object -Skip (${lineCount} - 1)
		if ($lineCount -and $lastLine -eq "") {
			[int]$lineCount = ${lineCount} - 2
		}
		[object]$result.script = $content | Select-Object -Index ($lnCfgEnd..$lineCount)
		[string]$result.hash = (Get-FileHash -Algorithm SHA256 -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes((($result.script)))))).Hash
	} else {
		return $false
	}
	return $result
}

function Update-ChrScript () {
	<#
		.SYNOPSIS
			Compare date and version, update if available
		.NOTES
			REMOTE  : README.md "Latest version: YYYYMMMDD"
			LOCAL   : chrupd.cmd " 20[2-3]\d{5} " (e.g. 20201231)
	#>
	[hashtable]$cmdParams = @{}
	<# TEST: $cmdParams += @{ Verbose = $true } #>
	if ($debug -ge 1) {
		$cmdParams += @{ WhatIf = $true }
		Write-Msg -o dbg, 1, Yellow "Update-ChrScript debug=`"$debug`" (!) NOT CHANGING FILES"
	}
	<# get date/version from readme #>
	[System.Net.ServicePointManager]::SecurityProtocol = @("Tls13", "Tls12", "Tls11", "Tls")
	[string]$ghApiUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("aHR0cHM6Ly9hcGkuZ2l0aHViLmNvbS9yZXBvcy9ta29ydGhvZi9jaHJ1cGQ="))
	<# skip api req when dot sourced or debugging, so we dont hit api rate limit #>
	if (!$dotSourced -and ($debug -eq 0)) {
		[pscustomobject]$ghReadmeObj = (
			ConvertFrom-Json(Invoke-WebRequest -UseBasicParsing -TimeoutSec 300 -Uri "$ghApiUrl/contents/README.md")
		)
	} else {
		<# TEST: fake new version = ghReadmeObj_20291231.json, old version = ghReadmeObj_20211002.json)) #>
		Write-Msg -o dbg, 1 "Update-ChrScript TEST MODE"
		[pscustomobject]$ghReadmeObj = (
			ConvertFrom-Json(Get-Content .\test\ghReadme_20291231.json)
		)
	}
	[string]$ghReadmeContent = [System.Text.Encoding]::UTF8.GetString(([System.Convert]::FromBase64String((($ghReadmeObj).content)))) -split "`r?`n"
	[string]$newDate = ($ghReadmeContent | Select-String -Pattern "Latest version.* 20[2-3]\d{5} ") -replace '.*Latest version: (20[2-3]\d{5}) .*', '$1'
	Write-Msg -o dbg, 1 "Update-ChrScript curScriptDate=`"$curScriptDate`" newDate=`"$newDate`""
	<# compare date in remote 'README.md' with local 'chrupd.cmd' #>
	if ($newDate -and (([DateTime]::ParseExact($newDate, 'yyyyMMdd', $null)) -gt ([DateTime]::ParseExact($curScriptDate, 'yyyyMMdd', $null)))) {
		Write-Msg -o tee "New chrupd version `"$newDate`" available, updating script..."
		Write-Msg
		<# SPLIT: current script file #>
		Write-Msg -o dbg, 1 "Update-ChrScript Split-Script `$scriptCmd=`"$scriptCmd`""
		$localSplit = Split-Script $(Get-Content "${scriptDir}\${scriptCmd}")
		<# SPLIT: new script content from github #>
		Write-Msg -o dbg, 1 "Update-ChrScript getting chrupd contents from api.github.com"
		[pscustomobject]$ghScriptObj = (
			ConvertFrom-Json(
				Invoke-WebRequest -UseBasicParsing -TimeoutSec 300 -Uri "$ghApiUrl/contents/chrupd.cmd"
			)
		)
		$ghScriptContent = [System.Text.Encoding]::UTF8.GetString(([System.Convert]::FromBase64String((($ghScriptObj).content)))) -split "`r?`n"
		Write-Msg -o dbg, 1 "Update-ChrScript Split-Script `"`$ghScriptContent`""
		if ($debug -ge 1) {
			Split-Script $ghScriptContent | Out-Null
		}
		if ($ghScriptContent) {
			$ghSplit = Split-Script $ghScriptContent
		} else {
			Write-Msg -o err, tee "Could not download new script, skipped update"
			break
		}
		<# write new script, merge current local config if found #>
		if ($ghSplit) {
			if ($localSplit) {
				$newContent = $ghSplit.head, $localSplit.config, $ghSplit.script
				Write-Msg -o dbg, 1 "Update-ChrScript localSplit.hash=`"$($localSplit.hash)`""
				Write-Msg -o dbg, 1 "Update-ChrScript    ghSplit.hash=`"$($localSplit.hash)`""
			} else {
				$newContent = $ghScriptContent
				Write-Msg -o warn "Current script configuration not found, using defaults"
			}
			if ( $(try { (&Test-Path "${scriptDir}\${scriptCmd}.tmp") } catch { $false }) ) {
				Write-Msg -o dbg, 1 "${scriptCmd}.tmp already exists, removing..."
				try {
					Remove-Item @cmdParams -ErrorAction 1 -WarningAction 1 "${scriptDir}\${scriptCmd}.tmp" -Force
				} catch {
					Write-Msg -o err, tee "Could not remove ${scriptCmd}.tmp"
					break
				}
			}
			try {
				Set-Content @cmdParams -EA 1 -WA 1 "${scriptDir}\${scriptCmd}.tmp" -Value $newContent
			} catch {
				Write-Msg -o err, tee "Could not write script, skipped update"
				break
			}
			<# replace 'in use' script only if we're running as ps1 (.\chrupd.ps1) #>
			if ($scriptCmd.Split(".")[1] -eq "ps1") {
				try {
					Move-Item @cmdParams -Force -EA 0 -WA 0 -Path "${scriptDir}\${scriptCmd}" -Destination "${scriptDir}\${scriptCmd}.bak"
				} catch {
					Write-Msg -o err, tee "Could not move `"${scriptCmd}`" to `"$contentCmd.bak`""
					break
				}
				try {
					Move-Item @cmdParams -Force -EA 0 -WA 0 -Path "${scriptDir}\${scriptCmd}.tmp" -Destination "${scriptDir}\${scriptCmd}"
				} catch {
					Write-Host -o err, tee "Could not move `"${scriptCmd}.tmp`" to `"$contentCmd`""
					break
				}
			}
		} else {
			Write-Msg -o err, tee "Unable to get new script, skipped update"
			break
		}
	} else {
		if ($cUpdate) {
			Write-Msg "No script updates available"
			Write-Msg
		} else {
			Write-Msg -o dbg, 1 "Update-ChrScript cUpdate=`"$cUpdate`" no updates available"
		}
	}
}

<# OPTION: update script and exit #>
if ($cUpdate) {
	Update-ChrScript
	Exit
}
<# OPTION: auto update #>
if ($cAutoUp -eq 1) {
	Update-ChrScript
}

<###################>
<# SCHEDULED TASKS #>
<###################>

<# 1) Normal (Windows 8+), uses Cmdlets [default]   #>
<# 2) Legacy (Windows 7), uses COM object           #>
<# 3) Command (Windows XP), uses schtasks.exe       #>

<# TASK: vars #>
$confirmParam = $true
if (-not (Test-Variable "tsMode")) {
	$tsMode = 1
}
[string]$vbsWrapper = $scriptDir + "\chrupd.vbs"
[string]$taskArgs = "-scheduler -name $name -arch $arch -channel $channel -cAutoUp $cAutoUp"
if ($proxy) {
if ($noVbs -eq 0) {
	[string]$taskCmd = "$vbsWrapper"
} else {
	[string]$taskCmd = 'powershell.exe'
	[string]$taskArgs = "-ExecutionPolicy ByPass -NoLogo -NoProfile -WindowStyle Hidden $scriptCmd $taskArgs"
}

<# XXX:	Alternative to hide window
		https://github.com/PowerShell/PowerShell/issues/3028
		cmd.exe /c start /min "" powershell -WindowStyle Hidden -ExecutionPolicy Bypass -Command ". 'C:\path\test.ps1'"  #>

<# TASK: VBS WRAPPER #>
$vbsContent = @"
'
' Wrapper for chrupd.cmd to hide window when using Task Scheduler
'
Dim WinScriptHost
For i = 0 to (WScript.Arguments.Count - 1)
	Args = Args & " " & WScript.Arguments(i)
Next
Set WinScriptHost = CreateObject("WScript.Shell")
WinScriptHost.Run Chr(34) & "${scriptDir}\\${scriptCmd}" & Chr(34) & " " & Args, 0
Set WinScriptHost = Nothing
"@

<# TASK: XML #>
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

<# CRTASK: create scheduled task #>
if ($crTask -eq 1) {
	if ( $(try { -not (&Test-Path $vbsWrapper) } catch { $false }) ) {
		Write-Msg "VBS Wrapper ($vbsWrapper) missing, creating...`r`n"
		Set-Content $vbsWrapper -ErrorAction Stop -WarningAction Stop -Value $vbsContent
		if ( $(try { -not (&Test-Path $vbsWrapper) } catch { $false }) ) {
			Write-Msg "Could not create VBS Wrapper, try again or use `"-noVbs`" to skip"
			exit 1
		}
	}
	switch ($tsMode) {
		1 { <# crtask: 1 normal mode #>
			$action = New-ScheduledTaskAction -Execute $taskCmd -Argument "$taskArgs" -WorkingDirectory "$scriptDir"
			$trigger = New-ScheduledTaskTrigger -RandomDelay (New-TimeSpan -Hour 1) -Daily -At 17:00
			if (-not (&Get-ScheduledTask -EA 0 -TaskName "$scriptName")) {
				Write-Msg $($taskMsg.create)
				try { (Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "$scriptName" -Description "$($taskMsg.descr)") | Out-Null }
				catch { Write-Msg "$($taskMsg.problem)`r`nERROR: `"$($_.Exception.Message)`"" }
			} else {
				Write-Msg $($taskMsg.exists)
			}
			if (&Get-ScheduledTask -EA 0 -TaskName "$scriptName" -OutVariable task) {
				if (Test-Variable "task") {
					Write-Msg ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}`r`n" -f ($task).TaskPath, ($task).TaskName, ($task).Description, ($task).State)
				} else {
					Write-Msg $taskMsg.failed
				}
			} else {
				Write-Msg ("{0}`r`n`r`n  {1}`r`n  {2}`r`n" -f $taskMsg.failed, $taskMsg.manual, $taskMsg.export)
			}
		}
		2 { <# crtask: 2 legacy mode #>
			$taskService = New-Object -ComObject("Schedule.Service")
			$taskService.Connect()
			$taskFolder = $taskService.GetFolder("\")
			[__ComObject]$regTask
			if (-not $(try { $taskFolder.GetTask("$scriptName") } catch { $false }) ) {
				Write-Msg $taskMsg.create
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
				try {
					$regTask = $taskFolder.RegisterTaskDefinition("$scriptName", $taskDef, 6, "", "", 3, "")
				}
				catch {
					Write-Msg "$($taskMsg.problem) ERROR: `"$($_.Exception.Message)`""
				}
				if (Test-Variable "regTask") {
					Write-Msg -o dbg, 1 "regTask = $regTask"
				} else {
					Write-Msg ("{0}`r`n`r`n  {1}`r`n  {2}`r`n" -f $taskMsg.failed, $taskMsg.manual, $taskMsg.export)
				}
			} else {
				Write-Msg $taskMsg.exists
			}
			if ( $(try { $taskFolder.GetTask("$scriptName") } catch { $false }) ) {
				$task = $taskFolder.GetTask("$scriptName")
				Write-Msg ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}.`r`n" -f $($task.Path), "", $($task.Definition.RegistrationInfo.Description), $($task.State))
			}
		}
		3 { <# crtask: 3 cmd mode #>
			Write-Msg "$($taskMsg.create)`r`n"
			Write-Msg "Creating Task XML File..."
			Set-Content "$env:TEMP\chrupd.xml" -Value $xmlContent
			<# $delay = (Get-Random -minimum 0 -maximum 59).ToString("00") #>
			<# $a = "/Create /SC DAILY /ST 17:${delay} /TN \\`"$scriptName`" /TR `"'$vbsWrapper' $taskArgs`"" #>
			$a = "/Create /TN \\`"$scriptName`" /XML `"$env:TEMP\chrupd.xml`""
			if ($confirm -eq 1) {
				$a = "$a /F"
			}
			$p = Start-Process -FilePath "$env:SystemRoot\system32\schtasks.exe" -ArgumentList $a -Wait -NoNewWindow -PassThru
			$handle = $p.Handle # cache proc.Handle
			$p.WaitForExit()
			if ($p.ExitCode -eq 0) {
				Write-Msg
			} else {
				Write-Msg ("`r`n{0}`r`n`r`n  {1}`r`n  {2}`r`n" -f $taskMsg.failed, $taskMsg.manual, $taskMsg.export)
			}
			try {
				Remove-Item -EA 0 -WA 0 -Force "$env:TEMP\chrupd.xml"
			} catch {
				$null
			}
			Write-Msg -o dbg, 1 "handle=$handle"
		}
	}
	exit 0
<# RMTASK: remove scheduled task #>
} elseif ($rmTask -eq 1) {
	switch ($tsMode) {
		1 { <# rmtask: 1 normal mode #>
			if ($confirm -eq 1) { $confirmParam = $false }
			if (&Get-ScheduledTask -EA 0 -TaskName "$scriptName") {
				Write-Msg "$($taskMsg.remove)`r`n"
				try {
					UnRegister-ScheduledTask -confirm:${confirmParam} -TaskName "$scriptName"
				} catch {
					Write-Msg "${taskMsg.problem}... $($_.Exception.Message)"
				}
			} else {
				Write-Msg "$($taskMsg.notask)`r`n"
			}
			if (&Get-ScheduledTask -EA 0 -TaskName "$scriptName" -OutVariable task) {
				if (Test-Variable "task") {
					Write-Msg ("Could not remove Task: `"{0}{1}`", Description: `"{2}`", State: {3}`r`n" -f ($task).TaskPath, ($task).TaskName, ($task).Description, ($task).State)
					Write-Msg ("{0}`r`n`r`n{1}`r`n" -f $taskMsg.rmfailed, $taskMsg.manual)
				}
			}
		}
		2 { <# rmtask: 2 legacy mode #>
			$taskService = New-Object -ComObject("Schedule.Service")
			$taskService.Connect()
			$taskFolder = $taskService.GetFolder("\")
			if ( $(try { $taskFolder.GetTask("$scriptName") } catch { $false }) ) {
				Write-Msg "$taskMsg.remove`r`n"
				try {
					$taskFolder.DeleteTask("$scriptName", 0)
				} catch {
					Write-Msg "${taskMsg.problem}... $($_.Exception.Message)"
				}
			} else {
				Write-Msg "$($taskMsg.notask)`r`n"
			}
			if ( $(try { $taskFolder.GetTask("$scriptName") } catch { $false }) ) {
				$task = $taskFolder.GetTask("$scriptName")
				Write-Msg ("Could not remove Task: `"{0}{1}`", Description: `"{2}`", State: {3}`r`n" -f "", ($task).TaskName, ($task).Description, ($task).State)
				Write-Msg ("{0}`r`n`r`n{1}`r`n" -f $taskMsg.rmfailed, $taskMsg.manual)
			}
		}
		3 { <# rmtask: 3 command mode #>
			Write-Msg "$taskMsg.remove`r`n"
			$a = "/Delete /TN \\`"$scriptName`""
			$p = Start-Process -FilePath "$env:SystemRoot\system32\schtasks.exe" -ArgumentList $a -Wait -NoNewWindow -PassThru
			$handle = $p.Handle # cache proc.Handle
			$p.WaitForExit()
			if ($p.ExitCode -eq 0) {
				Write-Msg
			} else {
				Write-Msg ("{0}`r`n`r`n{1}`r`n" -f $taskMsg.rmfailed, $taskMsg.manual)
			}
		}
	}
	exit 0
<# SHTASK: show scheduled task #>
} elseif ($shTask -eq 1) {
	switch ($tsMode) {
		1 { <# shtask: 1 normal mode #>
			if (&Get-ScheduledTask -EA 0 -TaskName "$scriptName" -OutVariable task) {
				if (Test-Variable "task") {
					$taskinfo = (&Get-ScheduledTaskInfo -TaskName "$scriptName")
					Write-Msg ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}." -f ($task).TaskPath, ($task).TaskName, ($task).Description, ($task).State)
					Write-Msg ("Actions: WorkingDirectory: `"{0}`", Execute: `"{1}`", Arguments: `"{2}`"" -f ($task).actions.WorkingDirectory, ($task).actions.Execute, ($task).actions.Arguments)
					Write-Msg ("TaskInfo: LastRunTime: `"{0}`", NextRunTime: `"{1}`", NumberOfMissedRuns: {2}`r`n" -f ($taskinfo).LastRunTime, ($taskinfo).NextRunTime, ($taskinfo).NumberOfMissedRuns)
				}
			} else {
				Write-Msg "$($taskMsg.notfound)`r`n"
			}
		}
		2 { <# shtask: 2 legacy mode #>
			$taskService = New-Object -ComObject("Schedule.Service")
			$taskService.Connect()
			$taskFolder = $taskService.GetFolder("\")
			if ( $(try { $taskFolder.GetTask("$scriptName") } catch { $false }) ) {
				$task = $taskFolder.GetTask("$scriptName")
				Write-Msg ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}." -f $($task.Path), "", $($task.Definition.RegistrationInfo.Description), $($task.State))
				Write-Msg ("Actions: WorkingDirectory: `"{0}`", Execute: `"{1}`", Arguments: `"{2}`"" -f $($($task.Definition.Actions).WorkingDirectory), $($($task.Definition.Actions).Path), $($($task.Definition.Actions).Arguments))
				Write-Msg ("TaskInfo: LastRunTime: `"{0}`", NextRunTime: `"{1}`", NumberOfMissedRuns: {2}`r`n" -f $($task.LastRunTime), $($task.NextRunTime), $($task.NumberOfMissedRuns))
			} else {
				Write-Msg "$($taskMsg.notfound)`r`n"
			}
		} <# shtask: 3 cmd mode #>
		3 {
			$a = "/Query /TN \\`"${scriptName}`" /XML"
			<# $p = Start-Process -FilePath "$env:SystemRoot\system32\schtasks.exe" -ArgumentList $a -Wait -NoNewWindow -PassThru #>
			<# $handle = $p.Handle # cache proc.Handle	#>
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
			if ($p.ExitCode -eq 0) {
				$stOut = (&$env:SystemRoot\system32\schtasks.exe /Query /TN `"$scriptName`" /FO LIST /V)
				$State = $(($stOut | Select-String -Pattern "^Status") -replace '.*: +(.*)$', '$1')
				$LastRunTime = $(($stOut | Select-String -Pattern "^Last Run Time") -replace '.*: +(.*)$', '$1')
				$NextRunTime = $(($stOut | Select-String -Pattern "^Next Run Time") -replace '.*: +(.*)$', '$1')
				Write-Msg ("Task: `"{0}{1}`"`r`nDescription: `"{2}`", State: {3}." -f $($stdout.Task.RegistrationInfo.URI), "", $($stdout.Task.RegistrationInfo.Description), $State)
				Write-Msg ("Actions: WorkingDirectory: `"{0}`", Execute: `"{1}`", Arguments: `"{2}`"" -f $($stdout.Task.Actions.Exec.WorkingDirectory), $($stdout.Task.Actions.Exec.Command), $($stdout.Task.Actions.Exec.Arguments))
				Write-Msg ("TaskInfo: LastRunTime: `"{0}`", NextRunTime: `"{1}`", NumberOfMissedRuns: {2}`r`n" -f $LastRunTime, $NextRunTime, "?")
			} else {
				Write-Msg "$($taskMsg.notfound)`r`nERROR: $stderr"
			}
		}
	}
	exit 0
<# TASK: create manually #>
} elseif ($manTask -eq 1) {
	Write-Msg "Check settings and retry, use a different tsMode (see help)"
	Write-Msg "Or try manually by going to: `"Start > Task Scheduler`" or `"Run taskschd.msc`".`r`n"
	Write-Msg "These settings can be used when creating a New Task :`r`n"
	Write-Msg ("  Name: `"{0}`"`r`n    Description `"{1}`"`r`n    Trigger: Daily 17:00 (1H random delay)`r`n    Action: `"{2}`"`r`n    Arguments: `"{3}`"`r`n    WorkDir: `"{4}`"`r`n" `
			-f $scriptName, $taskMsg.descr, $taskCmd, $taskArgs, $scriptDir)
	exit 0
<# TASK: export XML #>
} elseif ($xmlTask -eq 1) {
	Set-Content "$env:TEMP\chrupd.xml" -Value $xmlContent
	if ( $(try { (&Test-Path "$env:TEMP\chrupd.xml") } catch { $false }) ) {
		Write-Msg "Exported Task XML File to: `"$env:TEMP\chrupd.xml`""
		Write-Msg "File can be imported in Task Scheduler or `"schtasks.exe`".`r`n"
	} else {
		Write-Msg "Could not export XML"
	}
	exit 0
}

<### END OF SCHEDULED TASKS ####>


<#############>
<# FUNCTIONS #>
<#############>

function Test-HashFormat ([pscustomobject]$dataObj) {
	<#
		.SYNOPSIS
			Validate filehash format
	#>
	if ($script:ignHash -eq 0) {
		if (($dataObj.hashAlgo -match "md5|sha1|sha256") -and ($dataObj.hash -match "[0-9a-f]{32}|[0-9a-f]{40}|[0-9a-f]{64}")) {
			$dataObj.hashFormatMatch = $true
		} else {
			Write-Msg -o tee, err "No valid hash for installer/archive found, exiting..."
			exit 0
		}
		Write-Msg -o dbg, 1 "`$i=$i Test-HashFormat dataObj.hash=$($dataObj.hash)`r`n"
	} else {
		<# prompt user #>
		$_hMsg = "Ignoring hash. Could not verify checksum of installer/archive."
		Write-Msg -o Yellow "`r`n(!) ${_hMsg}`r`n    Press any key to abort or `"c`" to continue...`r`n"
		Write-Msg -o log "$_hMsg"
		$host.UI.RawUI.FlushInputBuffer()
		$startTime = Get-Date
		$waitTime = New-TimeSpan -Seconds 30
		While ((-not $host.ui.RawUI.KeyAvailable) -and ($curTime -lt ($startTime + $waitTime))) {
			$curTime = Get-Date
			$RemainTime = (($startTime - $curTime) + $waitTime).Seconds
			Write-Msg -o nnl, Yellow "`r    Waiting $($waitTime.TotalSeconds) seconds before continuing, ${remainTime}s left "
		}
		Write-Msg
		Write-Msg
		if ($host.ui.RawUI.KeyAvailable) {
			$x = $host.ui.RawUI.ReadKey("IncludeKeyDown, NoEcho")
			if ($x.VirtualKeyCode -ne "67") {
				Write-Msg -o tee "Aborting..."
				exit 1
			}
		}
		$dataObj.hashFormatMatch = $true
		$dataObj.hash = $null
		if (-not $dataObj.hashAlgo) {
			$dataObj.hashAlgo = "SHA1"
		}
	}
	return $dataObj
}

function Invoke-WebClient ($url, $file) {
	<#
		.SYNOPSIS
			Download file or text
	#>
	[System.Net.ServicePointManager]::SecurityProtocol = @("Tls12", "Tls11", "Tls")
	$wc = New-Object System.Net.WebClient
	if ($proxy) {
		$wc.Proxy = $webproxy
	}
	If ($file) {
		$wc.DownloadFile($url, $file)
	} else {
		$wc.DownloadString($_.Value.url)
	}
}

function Get-SevenZip () {
	<#
		.SYNOPSIS
			Find local or download 7z exe (used by Invoke-SevenZip only)
		.PARAMETER 7zConfig
			Paths and urls
	#>
	[string]$7zBin
	[bool]$7zCheck = $false
	[int]$fCnt = 0;
	<# check if 7zip is already present #>
	foreach ($7zBin in $7zConfig.Paths) {
		if (($7zBin -ne "") -and (Test-Path $7zBin -pathType Leaf -EA 0 -WA 0)) {
			$fCnt++
			break
		}
	}
	<# if not, try to download 7za.exe #>
	if ($fCnt -lt 1) {
		[int]$dlCnt = 1
		$7zConfig.Urls.GetEnumerator() | ForEach-Object {
			if ( $(try {-not (&Test-Path "7za.exe") } catch { $false }) -and ($7zCheck -eq $false) ) {
				Write-Msg -o tee "[$i/$($7zConfig.Urls.count)] Could not find 7z, downloading from `"$($_.Value.url)`" ..."
				if ($_.Key -eq "googlesource.com") {
					$ProgressPreference = 'SilentlyContinue'
					<# $7zaText = Invoke-WebRequest -Uri $_.Value.url #>
					$7zaText = Invoke-WebClient $_.Value.url
					<# convert downloaded text from b64 and write bytes to exe #>
					if ($7zaText.Length -gt 1024) {
						[IO.File]::WriteAllBytes("7za.exe", [System.Convert]::FromBase64String($7zaText))
					}
				} elseif ($_.Key -eq "7zip.org") {
						<# Invoke-WebRequest -Uri $_.Value.url -OutFile "7za920.zip" #>
						Invoke-WebClient $_.Value.url "7za920.zip"
						if ( $(try { (&Test-Path "7za920.zip") } catch { $false }) ) {
							Expand-Archive -Force .\7za920.zip 7za920.tmp
							Move-Item -Force -EA 0 -WA 0 -Path "7za920.tmp\7za.exe" -Destination "."
						}
				} else {
					<# Invoke-WebRequest -Uri $_.Value.url -OutFile "7za.exe" #>
					Invoke-WebClient $_.Value.url "7za.exe"
				}
				if (((Get-FileHash -WA 0 -EA 0 "7za.exe").Hash) -eq $_.Value.hash) {
					$7zBin = "7za.exe"
					$7zCheck = $true
					Write-Msg "Download successful (`"${7zBin}`" hash: OK)"
				} else {
					try {
						Remove-Item -WA 0 -EA 0 "7za.exe"
					} catch { $null }
					if ($i -lt ($7zConfig.Urls).count) {
						Write-Msg "Download failed, file hash did not match. Trying next URL..."
					} else {
						Write-Msg "Unable to download `"7za.exe`""
					}
				}
			$dlCnt++
			}
		}
	}
	return $7zBin
}

function Invoke-SevenZip ([string]$action, [string]$7zArgs) {
	<#
		.SYNOPSIS
			Run 7zip
		.PARAMETER action
			<listdir|extract>
		.PARAMETER 7zArgs
			[arguments to pass to 7z]
		.NOTES
			Source: http://www.mobzystems.com/code/7-zip-powershell-module/
	#>
	$7zBin = Get-SevenZip
	if (!$7zBin) {
		Write-Msg -o err, tee "7-Zip (`"7z.exe`") not found, exiting..."
		exit 1
	}
	if ($action -eq "listdir") {
		[string[]]$result = &$7zBin l $7zArgs
		[bool]$separatorFound = $false
		$result | ForEach-Object {
			if ($_.StartsWith("------------------- ----- ------------ ------------")) {
				if ($separatorFound) {
					<# Second separator! We're done #>
					Return
				}
				$separatorFound = -not $separatorFound
			} else {
				if ($separatorFound) {
					[string]$mode = $_.Substring(20, 5)
					[string]$name = $_.Substring(53).TrimEnd()
					if (($mode -match "^D") -and (-not $dirName)) {
						Write-Msg -o dbg, 1 "sevenZip name=`"$name`""
						$dirName = $name
						Return
					}
				}
			}
		}
		return $dirName
	} elseif ($action -eq "extract") {
		Write-Msg -o dbg, 1 "`$p = Start-Process -FilePath `"$7zBin`" -ArgumentList $7zArgs -NoNewWindow -PassThru -Wait"
		[process]$p = Start-Process -FilePath "$7zBin" -ArgumentList "$7zArgs" -NoNewWindow -PassThru -Wait
		[intptr]$handle = $p.Handle # cache proc.Handle
		Write-Msg dbg, 1 "handle=$handle"
		$p.WaitForExit()
		return $p.ExitCode
	}
}

function New-Shortcut ([string]$srcExe, [string]$srcExeArgs, [string]$dstPath) {
	<#
		.SYNOPSIS
			Create shortcut
	#>
	if (Test-Variable "srcExe") {
		if (&Test-Path $srcExe) {
			if ((Test-Variable "dstPath") -and ("$dstPath" -match "\.lnk")) {
				if (&Test-Path -WA 0 -EA 0 $dstPath) {
					try {
						Remove-Item -EA 0 -EA 0 -Force "$dstPath"
					} catch { $null }
				}
				$WshShell = New-Object -comObject WScript.Shell
				$Shortcut = $WshShell.CreateShortcut($dstPath)
				$Shortcut.Arguments = $srcExeArgs
				$Shortcut.TargetPath = $srcExe
				$Shortcut.Save()
				return $true
			}
		} else {
			Write-Msg -o err, tee "Shortcut target `"$srcExe`" does not exist"
		}
	} else {
		Write-Msg -o err, tee "Missing source .exe"
	}
	return $false
}

function Invoke-VirusTotal ([string]$apiKey, [string]$url, [string]$savePath, [string]$id) {
	<#
		.SYNOPSIS
			(TEST) Call Virus Total API to check downloaded file "id" i.e. hash
		.NOTES
			(TEST) Requires API KEY: https://www.virustotal.com/gui/join-us
	#>
	[hashtable]$cmdParams = @{}
	if ($debug -gt 2) {
		$cmdParams = @{ Verbose = $true; WhatIf = $true }
	}
	$scanUrl = "https://www.virustotal.com/gui/file/${id}"
	Write-Msg -o dbg,1 "Invoke-VirusTotal url=`"$url`" scanUrl=`"$scanUrl`""
	if ($url -notmatch $scanUrl) {
		Write-Msg -o warn "VirusTotal url from developer does not actual match file id"
	}
	if ([pscustomobject]$result = Invoke-RestMethod -Headers @{ 'x-apikey' = $apiKey } -Method GET "$scanUrl") {
		<# Write-Host "TEST: $($result.data.attributes.last_analysis_stats.Properties | ForEach-Object { $_.Name $_.Value })" #>
		[scriptblock]$_lastStats = {
			$result.data.attributes.last_analysis_stats.psobject.properties.name | ForEach-Object {
				$_, $result.data.attributes.last_analysis_stats.$_
			}
		}
		[scriptblock]$_lastDate = {
			[timezone]::CurrentTimeZone.ToLocalTime(
				([datetime]'1/1/1970').AddSeconds($($result.data.attributes.last_analysis_date))
			).toString("s")
		}
		[int]$_statsSuspicious = $result.data.attributes.last_analysis_stats.suspicious
		[int]$_statsMalicious = $result.data.attributes.last_analysis_stats.malicious
		[int]$_statsUndetected = $result.data.attributes.last_analysis_stats.undetected
		[string]$msgPre = "VirusTotal reports downloaded file as:"
		[string]$msgHits =	 "$(& $_lastDate) malicious($_statsMalicious) suspicious($_statsSuspicious)"
		Write-Msg -o dbg, 1 "Invoke-VirusTotal id=`"$id`" last_analysis_date=`"$(& $_lastDate)`" last_analysis_stats=`"$(& $_lastStats)`""
		if (($_statsSuspicious -lt 3) -and ($_statsMalicious -lt 2)) {
			if (($_statsSuspicious -eq 0) -and ($_statsMalicious -eq 0)) {
				Write-Msg "$msgPre OK"
			} else {
				Write-Msg -o warn "$msgPre $msgHits undetected($_statsUndetected), low risk - continueing..."
			}
		} else {
			Write-Msg -o err, tee "$msgPre $msgHits, exiting..."
			if (&Test-Path "$saveAsPath") {
				Remove-Item @cmdParams "$savePath"
			}
			exit 1
		}
	} else {
		Write-Msg -o dbg, 1 "Invoke-VirusTotal `"no result`""
	}
}

function Set-CdataHtml ([int]$idx, [string]$cdata, [hashtable]$cfg, [hashtable]$items, [pscustomobject]$cdataObj) {
	<#
		.SYNOPSIS
			Parse XML CDATA using 'htmlfile'
		.PARAMETER idx
			Index of XML RSS Item
	#>
	Write-Msg -o dbg, 1 "Set-CdataHtml `$i=$i"
	try {
		$html = New-Object -ComObject "htmlfile"
	} catch {
		Write-Msg -o err, tee "HTML filetype not supported, exiting..."
		exit 1
	}
	<# XXX: https://stackoverflow.com/a/48859819 #>
	try {
		<# This works in PowerShell with Office installed #>
		$html.IHTMLDocument2_write($cdata)
	} catch {
		<# This works when Office is not installed #>
		$_src = [System.Text.Encoding]::Unicode.GetBytes($cdata)
		$html.write($_src)
	}
	$html.getElementsByTagName('li') | ForEach-Object {
		$_name = $_.innerText.split(':')[0].ToLower() -replace '(\n|\r\n)', '_'
		$_value = $_.innerText.split(':')[1] -replace '^ ' -replace ' ?\(virus\?\)'
		<# Write-Msg dbg, 1 "name=$_name value=$_value" #>
		$cdataObj | Add-Member -MemberType NoteProperty -Name $_name -Value $_value -Force
		if ($_.getElementsByTagName('a')) {
			$_.getElementsByTagName('a') | ForEach-Object {
				<# $_name = $_.innerText.replace('virus?', 'virusTotalUrl') #>
				<# Write-Msg dbg, 1 "name=$_name value=$_value - nameProp=$($_.nameProp) hostname=$($_.hostname) - innerText=$($_.innerText.replace('?',''))" #>
				if (($_name -match $items[$name].filemask) -and ($_.hostname -match "www.virustotal.com")) {
					$cdataObj | Add-Member -MemberType NoteProperty -Name virusTotalUrl -Value $_.href -Force   # vtUrl_$($_name)
				}
				if ($_.innerHTML -match $items[$name].filemask) {
					$cdataObj | Add-Member -MemberType NoteProperty -Name url -Value $_.href -Force
				}
			}
		}
	}
	$cdataObj.titleMatch = $xml.rss.channel.Item[$idx].title -match $items[$name].author
	$cdataObj.editorMatch = $items[$name].author -match $cdataObj.editor
	$cdataObj.archMatch = $arch -ieq $cdataObj.architecture
	$cdataObj.channelMatch = $channel -ieq $cdataObj.channel
	foreach ($algo in "md5", "sha1", "sha256") {
		$_gethash = $cDataObj | Select-Object -ExpandProperty "*$($items[$name].filemask)*$algo" -EA 0 -WA 0
		if ($_gethash) {
			$cdataObj.hash = $_gethash
			$cdataObj.hashAlgo = $algo
		}
	}
	if ($debug -ge 1) {
		$cnt = 0
		if ($cdataObj.titleMatch) {
			$_tMsg = "Set-CdataHtml xml.rss.channel.Item.title=`"$($xml.rss.channel.Item[$idx].title)`" -match author=`"$($items[$name].author)`"`r`n"
			$cnt++
		}
		if ($cdataObj.editorMatch) {
			$_eMsg = "Set-CdataHtml `$idx=$idx author=`"$($items[$name].author)`" -match cdataObj.editor=`"$($cdataObj.editor)`"`r`n"
			$cnt++
		}
		if ($cnt -gt 0 ) {
			Write-Msg -o Yellow ("{0}`r`n{1}{2}{0}" -f ("-" * 80), $_tMsg, $_eMsg)
		}
		if ($debug -ge 9) {
			Write-Msg -o Magenta "DEBUG: `$idx=$idx outputting 'cdataObj' only, then Exit ..."
			$cdataObj
			Exit
		}
	}
	return $cdataObj
}

function Set-CdataRegex ([int]$idx, [string]$cdata, [hashtable]$cfg, [hashtable]$items, [pscustomobject]$cdataObj) {
	<#
		.SYNOPSIS
			Parse XML CDATA using Regular Expressions
		.PARAMETER idx
			Index of XML RSS Item
	#>
	Write-Msg -o dbg, 2 "Set-CdataRegex `$idx=$idx"
	<# DEBUG: regex matches - call this scriptblock *after* a '-match' line by using '&matches'
	$matches = {
		if ($xml.rss.channel.Item[$i].title -match ".*?(Marmaduke)") {$Matches[1]; $cdataObj.editorMatch = $true}
		Write-Msg -o dbg,2 "Matches[0], [1] = "; % {$Matches[0]}; % {$Matches[1]}}
	} #>
	$cdataObj.titleMatch = $xml.rss.channel.Item[$idx].title -match $items[$name].author
	$cdataObj.editorMatch = $cdata -match '(?i)' + $channel + '.*?(Editor: <a href="' + $items[$name].url + '/">' + $items[$name].author + '</a>).*(?i)' + $channel
	$cdataObj.archMatch = $cdata -match '(?i)' + $channel + '.*?(architecture: ' + $arch + ').*(?i)' + $channel
	$cdataObj.channelMatch = $cdata -match '(?i)' + $channel + '.*?(Channel: ' + $channel + ')'
	$cdataObj.version = $cdata -replace ".*(?i)$($channel).*?Version: ([\d.]+).*", '$1'
	$cdataObj.revision = $cdata -replace ".*(?i)$($channel).*?Revision: (?:<[^>]+>)?(\d{3}|\d{6,7})<[^>]+>.*", '$1'
	$cdataObj.date = $cdata -replace ".*(?i)$($channel).*?Date: <abbr title=`"Date format: YYYY-MM-DD`">([\d-]{10})</abbr>.*", '$1'
	$urlReHtml = ".*?(?i)$($channel).*?Download from.*?repository:.*?<li>"
	$urlReLink = "<a href=`"($($items[$name].repo)(?:v$($cdataObj.version)-r)?$($cdataObj.revision)(?i:-win$($arch.replace('-bit','')))?/"
	<# $urlReFile = "$($($items[$name].filemask).replace('.*',''))($($cdataObj.version).*\.7z)?)" #>
	$urlReFile = "$($items[$name].filemask)($($cdataObj.version).*\.7z)?)"
	$cdataObj.url = $cdata -replace "${urlReHtml}${urlReLink}${urlReFile}`">.*", '$1'
	$_hash = ($cdata -replace ".*?(?i)$($channel).*?<a href=`"$($cdataObj.url)`">$($items[$name].filemask)</a><br />(?:(sha1|md5|sha256): ([0-9a-f]{32}|[0-9a-f]{40}|[0-9a-f]{64})) .*", '$1 $2')
	if (-not ($_hash -eq $cdata)) {
		$cdataObj.hashAlgo, $cdataObj.hash = $_hash.split(' ')
	}
	$cdataObj.virusTotalUrl = $cdata -replace ".*(?i)$($cdataObj.hash) <small>\(<a href=`"(https://www.virustotal.com[^ ]+)`" [^ ]+=.*", '$1'
	foreach ($var in "version", "revision", "date", "url", "virusTotalUrl") {
		<# if ($(Invoke-Expression `$$var) -eq $cdata) { #>
		if ($cdataObj.$var -and (-not ([string]::IsNullOrWhiteSpace($cdataObj.$var)))) {
			if ($cdataObj.$var -eq $cdata) {
				Write-Msg -o dbg, 1 "Set-CdataRegex `$cdataObj.$var eq $var"
				<# Invoke-Expression ('{0}="{1}"' -f ($var -replace "^", "$"), $null); #>
				$cdataObj | Add-Member -MemberType NoteProperty -Name $var -Value "" -Force
			}
		}
	}

	<# DISABLED: author exception "Marmaduke"
	if ( ($($xml.rss.channel.Item[$idx].title) -match "Ungoogled") -and
		 ($cdata -match '(?i)' + $channel + '.*?(Editor: <a href="' + $items[$name].url + '/">' + "Marmaduke" + '</a>).*(?i)' + $channel) )
	{
		$cdataObj.titleMatch = $true
		$cdataObj.editorMatch = $true
		$items[$name].filemask += "$($cdataObj.version).*\.7z"
	} #>

	<# DISABLED: author exception "ThumbApps"
	elseif ($cdata -match '(?i)' + $channel + '.*?(Editor: <a href="' + $items[$name].url + '/">' + "ThumbApps" + '</a>).*(?i)' + $channel) {
		$cdataObj.titleMatch = $true
		$cdataObj.editorMatch = $true
		$items[$name].filemask += "${version}_Dev_32_64_bit.paf.exe"
		$cdataObj.revision = "thumbapps"
		$cdataObj.url = $cdata -replace "${urlReHtml}<a href=`"($($items[$name].repo)$($items[$name].filemask))`".*", '$1'
		$script:ignHash = 1
		Write-Msg -o tee "There is no hash provided for this installer"
	} #>

	if ($ignVer -eq 1) {
		$cdataObj.revision = '\d{6}'
		$cdataObj.url = $cdata -replace "${urlReHtml}<a href=`"($($items[$name].repo)(?:v[\d.]+-r)?$($cdataObj.revision)(?:-win$($arch.replace('-bit','')))?/$($items[$name].filemask))`".*", '$1'
		$vMsg = "Ignoring version mismatch between RSS feed and filename"
		Write-Msg -o nnl, Yellow "`r`n(!) $vMsg"
		Write-Msg
		Write-Msg -o log "$vMsg"
	}
	if ($debug -ge 1) {
		$cnt = 0
		if ($cdataObj.titleMatch) {
			$_tMsg = "Set-CdataRegex `$idx=$idx xml.rss.channel.Item.title=`"$($xml.rss.channel.Item[$idx].title)`" -match author=`"$($items[$name].author)`r`n"
			$cnt++
		}
		if ($cdataObj.editorMatch) {
			$_eMsg = "Set-CdataRegex `$idx=$idx cdataObj.editorMatch=`"$($cdataObj.editorMatch)`"`r`n"
			$cnt++
		}
		if ($cnt -gt 0 ) {
			Write-Msg -o Yellow ("{0}`r`n{1}{2}{0}" -f ("-" * 80), $_tMsg, $_eMsg)
		}
		if ($debug -ge 9) {
			Write-Msg -o Magenta "DEBUG: `$idx=$idx outputting 'cdataObj' only, then Exit ..."
			$cdataObj
			Exit
		}
	}
	return $cdataObj
}

function Read-RssFeed ([string]$rssFeed, [string]$cdataMethod) {
	<#
		.SYNOPSIS
			Parses RSS feed
		.NOTES
			Calls Set-CdataHtml() and Set-CdataRegex()
	#>
	<# ps object for cdata #>
	$cdataObj = New-Object -Type PSObject -Property @{
		date            = $null
		hash            = $null
		hashAlgo        = $null
		url             = $null
		revision        = $null
		version         = $null
		virusTotalUrl   = $null
		titleMatch      = $false
		editorMatch     = $false
		archMatch       = $false
		channelMatch    = $false
		urlMatch        = $false
		hashFormatMatch = $false
	}

	<# 	XXX: docs  https://paullimblog.wordpress.com/2017/08/08/ps-tip-parsing-html-from-a-local-file-or-a-string #>
	<# 		 test  $xml = [xml](Get-Content "test\windows-64-bit") #>

	<# MAIN OUTER WHILE LOOP: XML
	   loops over items 'title' and 'author'   #>
	$xml = [xml](Invoke-WebRequest -UseBasicParsing -TimeoutSec 300 -Uri $rssFeed)
	$i = 0
	while ($xml.rss.channel.Item[$i]) {
		Write-Msg -o dbg, 1, Cyan		"`$i=$i xml cdataMethod=$cdataMethod title=$($xml.rss.channel.Item[$i].title)"
		Write-Msg -o dbg, 1				"`$i=$i xml link = $($xml.rss.channel.Item[$i].link)"
		Write-Msg -o dbg, 2, DarkYellow	"`$i=$i xml description = $($xml.rss.channel.Item[$i].description."#cdata-section")"
		<# INNER WHILE LOOP: cdata html #>
		$xml.rss.channel.Item[$i].description."#cdata-section" | ForEach-Object {
			if ($cdataMethod -eq "htmlfile") {
				$cdataObj = Set-CdataHtml -idx $i -cdata $_ -cfg $cfg -items $items -cdataObj $cdataObj
			} elseif ($cdataMethod -eq "regexp") {
				$cdataObj = Set-CdataRegex -idx $i -cdata $_ -cfg $cfg -items $items -cdataObj $cdataObj
			}
			if ($cdataObj.url) {
				$cdataObj.urlMatch = $cdataObj.url -match ('^https://.*' + '(' + $cdataObj.version + ')?.*' + $cdataObj.revision + '.*' + $items[$name].filemask)
			} else {
				Write-Msg -o dbg, 1, Yellow "`$i=$i No download url found matching $('^https://.*' + '(' + $cdataObj.version + ')?.*' + $cdataObj.revision + '.*' + $items[$name].filemask)"
			}
			if ($debug -ge 1) {
				<# Write-Msg -o dbg, 1 "`$i=$i cdataMethod=$cdataMethod html `$_ = `r`n" $_ #>
				<# Write-Msg -o dbg, 1 "`$i=$i revision = $($cdataObj.revision) urlcheck =" ('^https://.*' + '(' + $cdataObj.version + ')?.*' + $cdataObj.revision + '.*' + $items[$name].filemask) #>
				'cdataObj.editorMatch', 'cdataObj.archMatch', 'cdataObj.channelMatch', 'cdataObj.version', 'channel', `
					'cdataObj.revision', 'cdataObj.date', 'cdataObj.url', 'cdataObj.hashAlgo', 'cdataObj.hash', 'cdataObj.virusTotalUrl' | ForEach-Object {
					Write-Host "DEBUG: `$i=$i ${_} ="$(Invoke-Expression `$$_)
				}
			}
			<# author/url match & hash check #>
			if ($cdataObj.editorMatch -and $cdataObj.urlMatch) {
				Test-HashFormat $cdataObj | Out-Null
				break
			}
		}
		$i++
		Write-Msg -o dbg, 1
	}
	return $cdataObj
}

function Read-GhJson ([string]$jsonUrl) {
	<#
		.SYNOPSIS
			Extract JSON values from GitHub Repos API
	#>
	<# ps object for json data #>
	$jdataObj = New-Object -Type PSObject -Property @{
		date            = $null
		hash            = $null
		hashAlgo        = $null
		url             = $null
		revision        = $null
		version         = $null
		virusTotalUrl   = $null
		titleMatch      = $true
		editorMatch     = $false
		archMatch       = $false
		channelMatch    = $false
		urlMatch        = $false
		hashFormatMatch = $false
	}
	<# get first release (=latest) #>
	if ($debug -eq 0) {
		$jdata = (ConvertFrom-Json(Invoke-WebRequest -UseBasicParsing -TimeoutSec 300 -Uri $jsonUrl))[0]
	} else {
		<#		"$repo/(justclueless|ungoogled-eloston)/releases.json"  #>
		<# XXX: To test/debug: skip request to prevent hitting api rate limit, instead download 1x" #>
		$jdata = (Get-Content test\releases-1.json | ConvertFrom-Json)[0]
	}
	<# EXAMPLE:
		[
			{
				"author": {
					"login": "justclueless",
				},
				"assets": [
					{
						"name": "chrome.packed.7z",
						"browser_download_url": "https://github.com/justclueless/chromium-win64/releases/download/v105.0.5155.0-r0-AVX2/chrome.packed.7z",
					}
				],
				"body": "..."
		...
	#>
	if ($debug -gt 1) {
		<# Write-Host "DEBUG: JSON contents:`r`n$($jdata)" #>
		Write-Host ("DEBUG: JSON match `$jdata.author.login=`"{0}`" -> `$items[`$name].author=`"{1}`"" -f $jdata.author.login, $items[$name].author)
		Write-Host ("DEBUG: JSON match `$jdata.url=`"{0}`" -> `$items[`$name].repo=`"{1}`"" -f $jdata.url, "$($items[$name].repo).*")
	}
	$jdataObj.editorMatch = ($jdata.author.login -eq $items[$name].author) -or ($jdata.author.login -eq "github-actions[bot]")
	$jdataObj.channelMatch = $channel -eq "dev"
	$jdataObj.urlMatch = $jdata.url -match "$($items[$name].repo).*"
	$jdataObj.version = $jdata.tag_name
	<# if ($jdata.body -match "Revision") {
			$jdataObj.revision = $jdata.body -replace [Environment]::NewLine, '' -replace '.*Revision ([a-f0-9]+-refs/branch-heads/[0-9]*@{#[0-9]*}).*', '$1'
	}  #>
	if ($jdata.published_at) {
		<# $jdataObj.date = $($jdata.published_at).Split('T')[0] #>
		$jdataObj.date = (Get-Date "$($jdata.published_at)").ToString("yyyy-MM-dd")
	}
	switch ($arch) {
		'64-bit' { $archPattern = 'x64|win64' }
		'32-bit' { $archPattern = 'x86' }
	}
	$script:urlMatch = $false
	$jdata.assets.browser_download_url | ForEach-Object {
		if ($debug -gt 1) {
			Write-Host "DEBUG: JSON foreach url -> $($_)"
		}
		if (-not $jdataObj.url -and ("$_" -match "$($items[$name].url)/releases/download/$($jdataObj.version)/$($items[$name].filemask).*($($archPattern))?.*")) {
			$script:urlMatch = $true
			$jdataObj.url = $_
		}
	}
	if (-not $script:urlMatch) {
		$jdataObj.url = $null
		$jdataObj.urlMatch = $false
	}
	if ($debug -gt 1) {
		Write-Host "DEBUG: JSON compare urls :"
		Write-Host "DEBUG: JSON   $($jdataObj.url)  (`$jdataObj.url)"
		Write-Host "DEBUG: JSON   $($items[$name].url)/releases/download/$($jdataObj.version)/$($items[$name].filemask)  (`$items.[`$name].url ...)"
	}
	$jdataObj.archMatch = ($jdataObj.url -match $archPattern) -or ($jdata.name -match $archPattern) -or ($jdata.body -match $archPattern)
	$jdataObj.hashAlgo = $jdata.body -replace [Environment]::NewLine, '' -replace ".*(md5|sha1|sha-1|sha256)[ :-].*", '$1' -replace "sha-1", "SHA1"
	if ($jdataObj.hashAlgo -eq "SHA1") {
		$len = 40
	} elseif ($jdataObj.hashAlgo -eq "SHA256") {
		$len = 64
	}
	if ($jdata.body) {
		$hashRe = (".*(?:$($($items[$name].filemask).replace(`".exe`",'(?:.exe)?')))[ :-]*([0-9a-f]{$($len)})")
		$vtRe = ("(https://www.virustotal.com[^ ]+)")
		$script:vtMatch = $false
		$jdata.body.Split([Environment]::NewLine) | ForEach-Object {
			if ($_ -match $hashRe) {
				$jdataObj.hash = $_ -replace $hashRe, '$1'
			}
			if ($script:vtMatch -eq $false -and $_ -match $vtRe) {
				$script:vtMatch = $true
				$jdataObj.virusTotalUrl = $_ -replace $vtRe, '$1'
			}
		}
	}
	if ($debug -gt 1) {
		'jdataObj.editorMatch', 'jdataObj.archMatch', 'jdataObj.channelMatch', 'jdataObj.version', 'channel', `
			'jdataObj.revision', 'jdataObj.date', 'jdataObj.url', 'jdataObj.hashAlgo', 'jdataObj.hash', 'jdataObj.virusTotalUrl' | ForEach-Object {
			Write-Host "DEBUG: JSON `$i=$i ${_} ="$(Invoke-Expression `$$_)
		}
	}
	<# author/url match & hash check #>
	if ($jdataObj.editorMatch -and $jdataObj.urlMatch) {
		<# author exception "Eloston" since they do not provide hashes #>
		if (($name -eq "Ungoogled-Eloston") -and (-not $jdataObj.hash)) {
			$script:ignHash = 1
		}
		Test-HashFormat $jdataObj | Out-Null
	}
	if ($debug -ge 8) {
		Exit
	}
	return $jdataObj
}

function Show-CheckBox ([bool]$state, [string]$c1 = "Green", [string]$ok = "OK", [string]$c2 = "Red", [string]$nok = "NOK") {
	<#
		.SYNOPSIS
			Print colored "[OK]" or "[NOK]" message
		.PARAMETER state
			If $state is $true output "$ok", else "$nok"
		.PARAMETER c1
			Color for $ok msg
		.PARAMETER ok
			Set msg to display if state is $true
		.PARAMETER c2
			Color for $nok msg
		.PARAMETER nok
			Set msg to display if state is $false
	#>
	if (Test-Variable "state") {
		Write-Msg -o nnl "["
		if ($state) {
			Write-Msg -o nnl, $c1 "$ok"
		} else {
			Write-Msg -o nnl, $c2 "$nok"
		}
		Write-Msg -o nnl "]"
	} else {
		Write-Msg -o nnl "[ ]"
	}
}

<### END OF FUNCTIONS ###>


<########>
<# MAIN #>
<########>

if ($dotSourced -and ($ignDotSrc -eq 0)) {
	Write-Msg -o Yellow "Dot sourced, exiting script (dotsourced=$dotSourced debug=$debug cAutoUp=$cAutoUp)"
	exit 0
}

<# OUTPUT: script title and winver #>
Write-Msg -o nnl, White, DarkGray " $scriptName"
Write-Msg -o nnl, Black, DarkGray " (${scriptCmd}-${curScriptDate}) "
Write-Msg "`r`n"
<# Write-Msg -o White "$("-" * 49)`r`n" #>
Write-Msg ("OS Detected: {0}`r`nTask Scheduler Mode: {1} `"{2}`"" -f $winVerResult.osFullName, $winverResult.tsModeName, $tsMode)

<# OUTPUT: logfile #>
if ($cfg.log) {
	if ($logFileOk) {
		Write-Msg "Logging to: `"$logFile`""
	} else {
		Write-Msg "Unable to write to logfile, showing output on console only`r`n"
	}
}

<# OUTPUT: start msg #>
Write-Msg -o log "Start (pid:$pid name:$($(Get-PSHostProcessInfo | Where-Object ProcessId -eq $pid).ProcessName) scheduler:$scheduler v:$curScriptDate )"

<# OUTPUT: current chrome version #>
if ($force -eq 1) {
	Write-Msg -o tee "Forcing update, ignoring currently installed Chromium version `"$curVersion`""
	Write-Msg
	$curVersion = "0.0.0.0"
} elseif ($fakeVer -eq 1) {
	Write-Msg -o dbg, 0 "Changing real current Chromium version `"$curVersion`" to fake value"
	$curVersion = "9.9.9.9-fake"
} else {
	if (Test-Variable "curVersion") {
		Write-Msg -o tee "Currently installed Chromium version: `"$curVersion`""
		Write-Msg
	} else {
		Write-Msg -o tee "Could not find Chromium, initial installation will be done by the downloaded installer..."
		$curVersion = "0.0.0.0"
	}
}

<# OUTPUT: used options #>
Write-Msg "Using the following settings:"
$_conf = [ordered]@{
	'Source' = if ($items[$name].url) { $items[$name].url -replace 'https://(?:www.)?([^/]+).*', '$1' } else { "Unknown" }
	'name'         = $name
	'architecture' = $arch
	'channel'      = $channel
}
$_conf.GetEnumerator() | ForEach-Object {
	Write-Msg -o nnl $_.Name
	Write-Msg -o nnl ' "'
	Write-Msg -o nnl, DarkGray $_.Value
	Write-Msg -o nnl '" '
	$cMsg += '{0} "{1}" ' -f $_.Name, $_.Value
}
Write-Msg "`r`n"
Write-Msg -o log "$cMsg"

<#####################################>
<# CALL RSS OR JSON PARSING FUNCTION #>
<#####################################>

[string]$errMsg = "Repository format `"$($items[$name].fmt)`" or URL `"$($items[$name].repo)`" not recognized"
if ($items[$name].fmt -eq "XML") {
	$dataObj = Read-RssFeed "https://chromium.woolyss.com/feed/windows-$($arch)" "htmlfile"
	if (!$dataObj.urlMatch) {
		Write-Msg -o dbg, 1, Magenta $(("-" * 80))
		Write-Msg -o dbg, 1, Magenta "No matching url found, trying alternative method..."
		Write-Msg -o dbg, 1, Magenta $(("-" * 80) + "`r`n")
		$dataObj = Read-RssFeed "https://chromium.woolyss.com/feed/windows-$($arch)" "regexp"
	}
} elseif ($items[$name].fmt -eq "JSON") {
	if ("$($items[$name].repo).*" -match "^https://api.github.com" ) {
		$dataObj = Read-GhJson "$($items[$name].repo)"
	} else {
		Write-Msg -o err, tee "$errMsg, exiting..."
		exit 1
	}
} else {
	Write-Msg -o err, tee "$errMsg, exiting..."
	exit 1
}

if ($debug -ge 1) {
	'dataObj.titleMatch', 'dataObj.editorMatch', 'dataObj.archMatch', 'dataObj.channelMatch', 'dataObj.urlMatch', 'dataObj.hashFormatMatch' | ForEach-Object {
		Write-Msg -o dbg, 1 "postparse ${_} ="$(Invoke-Expression `$$_)
	}
	Write-Msg
}

<# SHOW: any issues in parsed result user should see #>
[object]$_match = $dataObj.PSObject.Properties | Where-Object {
	$_.Name -like '*Match*' -and $_.Name -notlike '*titleMatch*'
}
[int]$_pcnt = ($_match | Where-Object Value -Like $false).Count
if ($_pcnt -gt 0) {
	Write-Msg "Found ${_pcnt} $(if ($_pcnt -gt 1) {"issues"} else {"issue"}):`r`n"
	Write-Msg -o nnl "Match "
	$_match | ForEach-Object {
		Write-Msg -o nnl ($_.Name -replace 'Match', '').ToLower()
		Show-CheckBox -state $_.Value -c1 "Gray" -ok "yes" -c2 "DarkRed" -nok "no"
		Write-Msg -o nnl " "
	}
	Write-Msg
	if (!$dataObj.editorMatch) {
		Write-Msg -o nnl "  "
		Show-CheckBox -state $false -c2 "DarkRed" -nok "X"
		Write-Msg -o nnl " check name setting: `"$($name)`""
		if ($cdataObj.editor) {
			Write-Msg -o nnl ", found author `"$($dataObj.author)`""
		}
		Write-Msg
	}
	if (!$dataObj.channelMatch) {
		Write-Msg -o nnl "  "
		Show-CheckBox -state $false -c2 "DarkRed" -nok "X"
		Write-Msg -o nnl " check channel setting: `"$($channel)`""
		if ($cdataObj.channel) {
			Write-Msg -o nnl ", found `"$($dataObj.channel)`""
		}
		Write-Msg
	}
	if (!$dataObj.archMatch) {
		Write-Msg -o nnl "  "
		Show-CheckBox -state $false -c2 "DarkRed" -nok "X"
		Write-Msg -o nnl " check architecture setting: `"$($arch)`""
		if ($cdataObj.architecture) {
			Write-Msg -o nnl ", found `"$($dataObj.architecture)`""
		}
		Write-Msg
	}
	if (!$dataObj.urlMatch) {
		Write-Msg -o nnl "  "
		Show-CheckBox -state $false -c2 "DarkRed" -nok "X"
		Write-Msg " unable to find correct url to download installer"
	}
	Write-Msg
	if (!($dataObj.editorMatch -and $dataObj.urlMatch)) {
		Write-Msg $noMatchMsg
		exit 0
	}
}

<##############################>
<# DOWNLOAD AND CHECK VERSION #>
<##############################>

[hashtable]$cmdParams = @{}
if ($debug -gt 2) {
	$cmdParams = @{ Verbose = $true; WhatIf = $true }
}
[string]$saveAsPath = "$env:TEMP\$($items[$name].filemask)"
if ($saveAsPath -notmatch "\.(exe|7z|zip)$") {
	$saveAsPath = ("{0}\{1}" -f $env:TEMP, $dataObj.url.Substring($dataObj.url.LastIndexOf("/") + 1))
}
if ( ($dataObj.editorMatch -eq 1) -and ($dataObj.archMatch -eq 1) -and ($dataObj.channelMatch -eq 1) -and ($dataObj.urlMatch -eq 1) -and ($dataObj.hashFormatMatch -eq 1) )	{
	if (($dataObj.url) -and ($dataObj.url -notmatch ".*$curVersion.*")) {
		if (( $(try { [version]('{0}.{1}.{2}' -f $curVersion.split('.')) -gt [version]('{0}.{1}.{2}' -f $dataObj.version.split('.') -replace ('[^0-9.]', '')) } catch { $false }) )) {
			$_nMsg = "Newer version `"$curVersion`" already installed, skipping `"$($dataObj.version)`""
			Write-Msg -o tee, err "$_nMsg"
			Write-Msg
			exit 1
		} else {
			[timespan]$ago = ((Get-Date) - ([DateTime]::ParseExact($dataObj.date, 'yyyy-MM-dd', $null)))
			[string]$_agoTxt =  if ($ago.Days -lt 1) { ($ago.Hours, "hours") } else { ($ago.Days, "days") }
			Write-Msg -o tee ("New Chromium version `"{0}`" from {1} is available ({2} ago)" -f $dataObj.version, $dataObj.date, $_agoTxt)
			if ($debug -ge 1) {
				Write-Msg -o dbg, 1 "Would have downloaded `$dataObj.url=`"$($dataObj.url)`""
				<# Write-Msg -o dbg, 1 "Would have used: `$saveAsPath=`"$saveAsPath`"" #>
				Write-Msg -o 1, Yellow ("{0}`r`n(!) Make sure saveAsPath ALREADY EXISTS to continue debugging" -f ("-" * 80))
				Write-Msg -o 1, Yellow ("    saveAsPath=`"$saveAsPath`"`r`n{0}" -f ("-" * 80))
			} else {
				if (&Test-Path "$saveAsPath") {
					Remove-Item @cmdParams "$saveAsPath"
				}
				Write-Msg -o tee "Downloading `"$($dataObj.url)`""
				Write-Msg -o tee "Saving as: `"$saveAsPath`""
				Invoke-WebClient $dataObj.url "$saveAsPath"
			}
		}
	} else {
		$_lMsg = "Latest Chromium version already installed"
		Show-CheckBox $true
		Write-Msg " $_lMsg`r`n"
		Write-Msg -o log "$_lMsg"
		exit 0
	}
} else {
	Write-Msg "$noMatchMsg"
	Write-Msg -o tee "No matching Chromium versions found, exiting..."
	Write-Msg
	exit 0
}

<######################################>
<# VERIFY HASH AND INSTALL OR EXTRACT #>
<######################################>

[string]$fileHash = (Get-FileHash -Algorithm $dataObj.hashAlgo "$saveAsPath").Hash
if ($script:ignHash -eq 1) {
	$dataObj.hash = $fileHash
	Write-Msg -o tee "Ignoring hash, calc value from downloaded installer: `"$($dataObj.hash)`""
}
if (-not ($dataObj.hashAlgo) -or ([string]::IsNullOrWhiteSpace($dataObj.hashAlgo))) {
	Write-Msg -o err, tee "Hash algorithm is missing, exiting..."
	exit 1
}
if (-not ($dataObj.hash) -or ([string]::IsNullOrWhiteSpace($dataObj.hash))) {
	Write-Msg -o err, tee "Hash is missing, exiting..."
	exit 1
}
	if ((Test-Variable "fileHash") -and ($fileHash -eq $dataObj.hash)) {
	$_hMsg = "$($dataObj.hashAlgo.ToUpper()) hash matches `"$($dataObj.hash)`""
	if (Test-Variable "vtApiKey") {
		Invoke-VirusTotal -apiKey "$vtApiKey" -url "$($dataObj.virusTotalUrl)" -savePath "$saveAsPath" -id "$($fileHash.ToLower())"
	} else {
		Write-Msg -o dbg, 1 "VirusTotal API key not found, skipped check"
	}
	if ($saveAsPath -match "\.exe$") {
		[string]$fileFmt = "EXECUTABLE"
		Write-Msg -o tee "$_hMsg"
		Write-Msg -o tee "Executing `"$($saveAsPath.Substring($saveAsPath.LastIndexOf("\") + 1))`" "
	} elseif ($saveAsPath -match "\.(7z|zip)$") {
		[string]$fileFmt = "ARCHIVE"
		[string]$extractPath = ""
		$i = 0
		foreach ($extractPath in $archiveInstallPaths) {
			if (($extractPath -ne "") -and (Test-Path -pathType Container -EA 0 -WA 0 $extractPath)) {
				$i++
				break
			}
		}
		if ($i -gt 0) {
			Write-Msg -o tee "Extracting to `"$extractPath`""
		} else {
			Write-Msg -o err, tee "Could not find dir to extract to, exiting..."
			exit 1
		}
	}
	<# TEST: if ($fakeVer -eq 1) { $saveAsPath += "-FakeVer" } #>

	<# print 'ok' message and optional $_dMsg #>
	[scriptblock]$_doneMsg = {
		Show-CheckBox $true
		Write-Msg " Done. "
		Write-Msg -o Yellow "`r`n${_dMsg}."
		Write-Msg -o log "Done. $_dMsg"
	}

	<# handle "executable" (installer exe) and "archive" (7z) #>
	if ($fileFmt -eq "EXECUTABLE") {
		[object]$exeArgs = @("--do-not-launch-chrome")
		if ($sysLvl -eq 1) {
			$exeArgs += "--system-level"
			if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
				Write-Msg -o Yellow "Start this script as Administrator to run installer"
			}
		}
		Write-Msg -o dbg, 1 "`$p = Start-Process -FilePath `"$saveAsPath`" -ArgumentList $exeArgs -Wait -NoNewWindow -PassThru"
		$p = Start-Process -FilePath "$saveAsPath" -ArgumentList $exeArgs -Wait -NoNewWindow -PassThru
		if ($p.ExitCode -eq 0) {
			$_dMsg = "New Chromium version will be used on next app (re)start"
			& $_doneMsg
		} else {
			Write-Msg -o err, tee "Something went wrong while executing installer..."
			if ($p.ExitCode) {
				Write-Msg -o err, tee "ExitCode $($p.ExitCode)"
			}
		}
		if (&Test-Path $installLog) {
			Write-Msg -o log, Red "Installer logfile: $installLog"
		}
	} elseif ($fileFmt -eq "ARCHIVE") {
		$arcDir = &Invoke-SevenZip "listdir" "$saveAsPath"
		[string]$lnkTarget = "${extractPath}\${arcDir}\chrome.exe"
		if ($arcDir) {
			if ((-not (&Test-Path "${extractPath}\${arcDir}")) -or ($appDir -eq 1)) {
				$retExtract = &Invoke-SevenZip "extract" "x $saveAsPath -o${extractPath} -y"
				if (($retExtract -eq 0) -and (&Test-Path "${extractPath}\${$arcDir}")) {
					<# XXX: for option '-arcdir' move chrome to output dir, e.g. :
					   		%AppData%\Chromium\Application\<name>\ungoogled-chromium-123.456  #>
					if ($appDir -eq 1) {
						$lnkTarget = "${extractPath}\${name}\chrome.exe"
						if (&Test-Path -pathType Container "${extractPath}\${name}") {
							Remove-Item @cmdParams -EA 0 -WA 0 -Recurse -Force "${extractPath}\${name}"
						}
						try {
							Rename-Item @cmdParams -EA 1 -WA 1 -Force "${extractPath}\${arcDir}" "${extractPath}\${name}"
						} catch {
							Write-Msg -o err, tee "Could not move Chromium folder"
							exit 1
						}
					}
					$_dMsg = "New Chromium version extracted to `"${extractPath}\${itemDir}`""
					<# $lnkName = "$env:USERPROFILE\Desktop\Chromium $version.lnk" #>
					[string]$lnkName = "$env:USERPROFILE\Desktop\Chromium.lnk"
					Write-Msg -o dbg, 1 "arcDir = `"$arcDir`""
					Write-Msg -o dbg, 1 "itemDir = `"$itemDir`""
					Write-Msg -o dbg, 1 "lnkTarget = `"$lnkTarget`""
					Write-Msg -o dbg, 1 "linkName = `"$lnkName`""
					$retShortcut = &New-Shortcut -srcExe "$lnkTarget" -srcExeArgs "$srcExeArgs" -dstPath "$lnkName"
					if (-not $retShortcut) {
						Write-Msg -o err, tee "Could not create shortcut on Desktop"
					} else {
						$_dMsg += " and shortcut created on Desktop"
					}
					& $_doneMsg
				} else {
					Write-Msg -o err, tee "Could not extract `"$saveAsPath`", exiting..."
					exit 1
				}
			} else {
				Write-Msg -o err, tee "Directory `"${extractPath}\${arcDir}`" already exists, exiting..."
				exit 1
			}
		} else {
			Write-Msg -o err, tee "No directory to extract found inside archive `"$saveAsPath`", exiting..."
			exit 1
		}
	}
} else {
	Write-Msg -o err, tee "$($dataObj.hashAlgo.ToUpper()) hash does NOT match: `"$($dataObj.hash.ToUpper())`". Exiting..."
	exit 1
}
Write-Msg
