BeforeAll {
	<#
	Import-Script `
		-EntryPoint Write-Msg `
		-Path $PSScriptRoot/../chrupd.ps1 
	#>
	. $PSScriptRoot/../chrupd.ps1
	$xml = [xml](Get-Content test/windows-64-bit)
	$cdata = @" 
	description =  <strong>Stable version</strong><ul><li>Editor: <a href="https://chromium.woolyss.com/">Hibbiki</a></li><li>Architecture: 64-bit</li><li>Channel: stable</li><li>Version: 91.0.4472.101</li><li>Revision: 870763</li><li>Codecs: all audio/video codecs</li><li>Date: <abbr title="Date format: YYYY-MM-DD">2021-06-10</abbr></li></ul> Download from Github repository: <ul><li><a href="https://github.com/Hibbiki/chromium-win64/releases/download/v91.0.4472.101-r870763/mini_installer.sync.exe">mini_installer.sync.exe</a><br />sha1: 8fb1ede28391ad944059d318340017524117e01d <small>(<a href="https://www.virustotal.com/gui/file/8fb1ede28391ad944059d318340017524117e01d/detection" target="_blank" rel="noopener noreferrer">virus?</a>)</small></li></ul><ul><li><a href="https://github.com/Hibbiki/chromium-win64/releases/download/v91.0.4472.101-r870763/chrome.sync.7z">chrome.sync.7z</a><br />sha1: bfb39c9e7bfb595ce134436aeb34d31053f342b2 <small>(<a href="https://www.virustotal.com/gui/file/bfb39c9e7bfb595ce134436aeb34d31053f342b2/detection" target="_blank" rel="noopener noreferrer">virus?</a>)</small></li></ul><small>Source: <a href="https://chromium.woolyss.com/">https://chromium.woolyss.com/</a></small>
"@

	$cdataObj = New-Object -Type PSObject -Property @{
		titleMatch   = $true
		editorMatch  = $true
		archMatch    = $true
		channelMatch = $true
		version      = "91.0.4472.101"
		channel      = "stable"
		revision     = "870763"
		date         = "2021-06-10"
		url          = "https://github.com/Hibbiki/chromium-win64/releases/download/v91.0.4472.101-r870763/mini_installer.sync.exe"
		hashAlgo     = "sha1"
		hash         = "8fb1ede28391ad944059d318340017524117e01d"
		virusTotalUrl = "https://www.virustotal.com/gui/file/8fb1ede28391ad944059d318340017524117e01d/detection"
	}
}

Describe "cdataRegex" {
	#$name = "Hibbiki"
	It "parse cdata using 'regex'" {
		$debug = 2
		Set-CdataRegex -idx 0 -cdata $cdata -cfg $cfg -items $items -cdataObj $cdataObj | ConvertTo-Json | Should -Be `
			$($cdataObj | ConvertTo-Json)
	}
}
