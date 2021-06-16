BeforeAll {
    Push-Location
    Start-Transaction
    Set-Location ..
    Import-Script `
    -EntryPoint Write-Msg `
    -Path $PSScriptRoot/../chrupd.ps1 
}

Describe "cdataHtml" {
	#$xml = $(Get-Content test.xml | ConvertTo-Xml)
	$global:xml = [xml](Get-Content .\windows-64-bit)
	$cdata = @"
	description =  <strong>Stable version</strong><ul><li>Editor: <a href="https://chromium.woolyss.com/">Hibbiki</a></li><li>Architecture: 64-bit</li><li>Channel: stable</li><li>Version: 91.0.4472.101</li><li>Revision: 870763</li><li>Codecs: all audio/video codecs</li><li>Date: <abbr title="Date format: YYYY-MM-DD">2021-06-10</abbr></li></ul> Download from Github repository: <ul><li><a href="https://github.com/Hibbiki/chromium-win64/releases/download/v91.0.4472.101-r870763/mini_installer.sync.exe">mini_installer.sync.exe</a><br />sha1: 8fb1ede28391ad944059d318340017524117e01d <small>(<a href="https://www.virustotal.com/gui/file/8fb1ede28391ad944059d318340017524117e01d/detection" target="_blank" rel="noopener noreferrer">virus?</a>)</small></li></ul><ul><li><a href="https://github.com/Hibbiki/chromium-win64/releases/download/v91.0.4472.101-r870763/chrome.sync.7z">chrome.sync.7z</a><br />sha1: bfb39c9e7bfb595ce134436aeb34d31053f342b2 <small>(<a href="https://www.virustotal.com/gui/file/bfb39c9e7bfb595ce134436aeb34d31053f342b2/detection" target="_blank" rel="noopener noreferrer">virus?</a>)</small></li></ul><small>Source: <a href="https://chromium.woolyss.com/">https://chromium.woolyss.com/</a></small>
"@
	$cfg = @{
		editor   = "Hibbiki";       <# Editor of Chromium release                  #>
		arch     = "64bit";         <# Architecture: 32bit or 64bit (default)      #>
		channel  = "stable";        <# dev, stable                                 #>
		proxy    = "";              <# set <uri> to use a http proxy               #>
		linkArgs = "";              <# see '.\chrupd.cmd -advhelp'                 #>
		log      = $True            <# enable or disable logging <$True|$False>    #>
		cAutoUp  = $True            <# auto update this script <$True|$False>      #>
	};
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
		"Ungoogled-Portable" = @{
			title    = "Ungoogled-Portable";
			editor   = "Portapps";
			fmt      = "XML";
			url      = "https://$woolyss";
			repo     = "https://github.com/portapps/ungoogled-chromium-portable/releases/";
			filemask = "ungoogled-chromium-"
			alias    = "Ungoogled-Portapps"
		};
		"RobRich"   =	@{
			title    = "RobRich";
			editor   = "RobRich";
			fmt      = "XML";
			url      = "https://$woolyss";
			repo     = "https://github.com/RobRich999/Chromium_Clang/releases/download/";
			filemask = "mini_installer.exe"
		};
	}
    $cdataObj = New-Object -Type PSObject -Property @{
		editorMatch = $True
		archMatch = $True
		channelMatch = $True
		version = "91.0.4472.101"
		channel = "stable"
		revision = "870763"
		date = "2021-06-10"
		url = "https://github.com/macchrome/winchrome/releases/download/v91.0.4472.101-r870763-Win64/ungoogled-chromium-91.0.4472.101-1_Win64.7z"
		hashAlgo = "sha1"
		hash = "8926273c4d82cf65a8735c8f0bba767a1735e9e2"
		virusTotal = "https://www.virustotal.com/gui/file/8926273c4d82cf65a8735c8f0bba767a1735e9e2/detection"
	}
    It "parse cdata using 'htmlfile'" {
        cdataHtml(1, $cdata, $cfg, $items, $cdataObj) | Should -Be $null
    }
}

AfterAll {
    Pop-Location
}
