<# :
@echo off
setlocal
set "POWERSHELL_BAT_ARGS=%*"
if defined POWERSHELL_BAT_ARGS set "POWERSHELL_BAT_ARGS=%POWERSHELL_BAT_ARGS:"="""%"
endlocal & powershell -NoLogo -NoProfile -Command "$input | &{ [ScriptBlock]::Create( ( Get-Content \"%~f0\" ) -join [char]10 ).Invoke( @( &{ $Args } %POWERSHELL_BAT_ARGS% ) ) }"
goto :EOF
#>

<# -------------------------------------------------------------------------- #>
<# 20171218 MK: Simple Chromium Updater (chrupd.cmd)   										    #>
<# -------------------------------------------------------------------------- #>
<# Uses RSS feed from "chromium.woolyss.com" to download and install latest   #>
<# Chromium version, if a newer version is available. Options can be set      #>
<# below or using command line arguments (try "chrupd.cmd -h")                #>
<#  - default is to get the "stable" 64-bit "nosync" Installer by "Nik"       #>
<#  - verifies sha1/md5 hash and runs installer                               #>
<# -------------------------------------------------------------------------- #>

<# NOTE: for easy execution this PowerShell script is embedded in a Batch .CMD
   file using a "polyglot wrapper". It can be renamed to chrupd.ps1. More info:
   - https://blogs.msdn.microsoft.com/jaybaz_ms/2007/04/26/powershell-polyglot
   - https://stackoverflow.com/questions/29645  #>

<# -------------------------------------------------------------------------- #>
<# CONFIGURATION:                                                             #>
<# -------------------------------------------------------------------------- #>
<# See "chrupd.cmd -h" for possible settings (or check below ;)
<# -------------------------------------------------------------------------- #>

$editor = "Nik"
$channel = "stable"
$getFile = "chromium-nosync.exe"

<# -------------------------------------------------------------------------- #>
<# END OF CONFIGURATION #>
<# -------------------------------------------------------------------------- #>

<# $editor = "The Chromium Authors"; channel = "dev" #>
$chkSite = "chromium.woolyss.com"
$rssFeed = "https://$chkSite/feed/windows-64-bit"
$saveAs = "$env:TEMP\$getFile"
$debug = "0"

Write-Host -ForeGroundColor White -NoNewLine "`r`nSimple Chromium Updater"; Write-Host " (chrupd.cmd)"
Write-Host "------------------------------------`r`n"

If ($Args -iMatch "[-/]h") {
  Write-Host "Uses RSS feed from `"$chkSite`" to download and install latest"
	Write-Host "Chromium version, if a newer version is available.`r`n"
	Write-Host "USAGE: chrupd.cmd -[editor|channel|getFile]" "`r`n"
	Write-Host "`t" "-editor  can be set to [Nik|RobRich|Chromium]"
	Write-Host "`t" "-channel can be set to [stable|dev]"
	Write-Host "`t" "-getFile can be set to [chromium-sync.exe|chromium-nosync.exe]`r`n"
	Write-Host "EXAMPLE: chrupd.cmd -editor Nik -channel stable -getFile chromium-nosync.exe" "`r`n"
	Write-Host "NOTES:`t - Option `"getFile`" is only used if editor is set to `"Nik`""
	Write-Host "`t" "- Settings are Case Sensive" 
	Write-Host "`t" "- Options can also be set permanently using variables inside script"
	Exit 0
}
ElseIf (($Args.length % 2) -eq 0) {
	$i=0; While ($Args -is [Object[]] -And $i -lt $Args.length) {
		If (($Args[$i] -Match "^-") -And ($Args[($i+1)] -Match "^[\w\.]")) {
			Invoke-Expression ('{0}="{1}"' -f ($Args[$i] -Replace "^-", "$"), $Args[++$i].Trim());
		} 
	$i++
	}
}

If ( $editor -ceq "Nik" ) { $website = "https://$chkSite"; $fileSrc = "https://github.com/henrypp/chromium/releases/download/" }
ElseIf ( $editor -ceq "RobRich" ) { $website = "https://$chkSite";	$fileSrc = "https://github.com/RobRich999/Chromium_Clang/releases/download/";  $getFile = "mini_installer.exe" }
ElseIf ( $editor -cMatch "Chromium|The Chromium Authors" ) {	$website = "https://www.chromium.org"; $fileSrc = "https://storage.googleapis.com/chromium-browser-snapshots/Win_x64/";	$getFile = "mini_installer.exe" }
Else { Write-Host -ForeGroundColor Red "ERROR: Settings incorrect - check editor `"$editor`", exiting"; Exit 1 }
If (-Not ($channel -cMatch "^(stable|dev)$")) { Write-Host -ForeGroundColor Red "ERROR: Invalid channel `"$channel`", exiting"; Exit 1 }
If (-Not ($getFile -cMatch "^(chromium-sync.exe|chromium-nosync.exe)$")) { Write-Host -ForeGroundColor Red "ERROR: Invalid getFile `"$getFile`", exiting"; Exit 1 }

$curVersion = (Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Chromium).Version

Write-Host "Currently installed version: `"$curVersion`"`r`n"

$xml = [xml](Invoke-WebRequest $rssFeed)
$i = 0; While ($xml.rss.channel.item[$i]) {
  $editorMatch = 0; $archMatch = 0; $chanMatch = 0; $urlMatch = 0; $hashMatch = 0
	$xml.rss.channel.item[$i].description."#cdata-section" | ForEach {
  	If ($_ -Match '(?i)' + $channel + '.*?(Editor: <a href="' + $website + '/">' + $editor + '</a>).*(?i)' + $channel) { $editorMatch = 1 }
  	If ($_ -Match '(?i)' + $channel + '.*?(Architecture: 64-bit).*(?i)' + $channel) { $archMatch = 1 }
  	If ($_ -Match '(?i)' + $channel + '.*?(Channel: ' + $channel + ')') { $chanMatch = 1 }
  	$version = [regex]::Replace($_, '.*(?i)' + $channel + '.*?Version: ([\d.]+).*', '$1')
  	$revision = [regex]::Replace($_, '.*(?i)' + $channel + '.*?Revision: (?:<[^>]+>)?(\d{6})<[^>]+>.*', '$1')
  	$date = [regex]::Replace($_, '.*(?i)' + $channel + '.*?Date: <abbr title="Date format: YYYY-MM-DD">([\d-]{10})</abbr>.*', '$1')
  	$url = [regex]::Replace($_, '.*?(?i)' + $channel + '.*?Download from.*?repository: .*?<li><a href="(' + $fileSrc + '(?:v' + $version + '-r)?' + $revision + '(?:-win64)?/' + $getFile + ')".*', '$1')
	  If ($url -Match ('^https://.*' + '(' + $version + ')?.*' + $revision + '.*' + $getFile + '$') ) {	
		 	$urlMatch = 1
		  $tmpHash = [regex]::Replace($_, '.*?(?i)' + $channel + '.*?<a href="' + $url + '">' + $getFile + '</a> - (?:(sha1|md5): ([0-9a-f]{32}|[0-9a-f]{40}))</li>.*', '$1 $2')
	   	$hashAlgo, $hash = $tmpHash.ToUpper().split(' ')
	   	If (($hashAlgo) -And ($hash)) { $hashMatch = 1 }
	    Break
	  }
  }
$i++
}

If (($editorMatch -eq 1) -And ($archMatch -eq 1) -And ($chanMatch -eq 1) -And ($urlMatch -eq 1) -And ($hashMatch -eq 1)) {
  If (($url) -And ($url -NotMatch ".*$curVersion.*")) {
  $ago = ((Get-Date)  - ([DateTime]::ParseExact($date,'yyyy-MM-dd', $null)))
  If ($ago.Days -lt 1) { $agoTxt = ($ago.Hours, "hours") } Else { $agoTxt = ($ago.Days, "days")	}
	Write-Host "Using these settings:"
	Write-Host "checkSite: `"$chkSite`", Editor: `"$editor`", Channel: `"$channel`"`r`n"
  Write-Host "New version `"$version`" from $date is available ($agoTxt ago)"
	  If ($debug -eq 1) {
	    If (&Test-Path "$saveAs") { Write-Host "DEBUG: Would have deleted $saveAs" }
		  Write-Host "DEBUG: Downloading `"$url`" to `"$saveAs`""
	  } Else {
	    If (&Test-Path "$saveAs") { Remove-Item "$saveAs" }
	    Write-Host "Downloading `"$url`" to `"$saveAs`""
	    $wc = New-Object System.Net.WebClient
	    $wc.DownloadFile($url, "$saveAs")
	  }
	} Else {
		Write-Host "Latest version already installed"
	  Exit 0;
	}
} Else {
	Write-Host "No matching versions found, exiting..."
	Exit 0;
}

If ((Get-FileHash -Algorithm $hashAlgo "$saveAs").Hash -eq $hash) {
	Write-Host "$hashAlgo Hash matches `"$hash`""
	Write-Host "Executing `"$getFile`"..."
	If ($debug -eq 1) { 
	  Write-Host "DEBUG: $p = Start-Process -FilePath `"$saveAs`" -ArgumentList `"--do-not-launch-chrome`" -Wait -NoNewWindow -PassThru"
	} Else { 
    $p = (Start-Process -FilePath "$saveAs" -ArgumentList "--do-not-launch-chrome" -Wait -NoNewWindow -PassThru)
	}
  If ($p.ExitCode -eq 0) {
	 	Write-Host -NoNewLine "Done. "; Write-Host -ForeGroundColor Yellow "Please restart Chromium"
	} Else {
		Write-Host -ForeGroundColor Red -NoNewLine "ERROR: after executing `"$getFile`""
		If ($p.ExitCode) { Write-Host -ForeGroundColor Red  ":" $p.ExitCode }
	  If (&Test-Path "$env:TEMP\chromium_installer.log") { Write-Host -ForeGroundColor Red -NoNewLine "Log file: $env:TEMP\chromium_installer.log" }
	}
} Else {
  Write-Host -ForeGroundColor Red "ERROR: $hashAlgo Hash does NOT match `"$hash`", exiting..."
  Exit 1;
}
