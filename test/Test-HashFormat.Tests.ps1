BeforeAll {
	<#
    Import-Script `
		-EntryPoint Write-Msg `
		-Path $PSScriptRoot/../chrupd.ps1 
	#>
	. $PSScriptRoot\..\chrupd.ps1 | Out-Null

	$dataObj = New-Object -Type PSObject -Property @{
		archMatch=$True;
		hashFormatMatch=$False;
		channelMatch=$True;
		urlMatch=$True;
		editorMatch=$True;
		hashAlgo="sha1";
		hash="e73c8314c2a4991542c14f9ca4ad5a1657f408ca";
		titleMatch=$True;
		editor="Hibbiki";
		architecture="64-bit";
		channel="stable";
		version="106.0.5249.91";
		revision="1036826";
		codecs="all audio/video codecs";
		date="2022-10-01";
		"mini_installer.sync.exe_sha1"="e73c8314c2a4991542c14f9ca4ad5a1657f408ca";
		url="https://github.com/Hibbiki/chromium-win64/releases/download/v106.0.5249.91-r1036826/mini_installer.sync.exe";
		virusTotalUrl="https://www.virustotal.com/gui/file/e73c8314c2a4991542c14f9ca4ad5a1657f408ca/detection";  
		"chrome.sync.7z_sha1"="31a8bddd11b0c688d6022dd3770d50221f866f76"
	}
}

Describe "Test-HashFormat" {
    It "validate hash format" {
		$testDataObj = $dataObj.psobject.copy()
		$testDataObj.hashFormatMatch = $True
		Test-HashFormat $dataObj | ConvertTo-Json | Should -Be $($testDataObj | ConvertTo-Json)
    }
}
