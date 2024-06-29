BeforeAll {
	<#
    function Write-Host($a) {
        Write-Output $a
    }
    Import-Script `
    	-EntryPoint Write-Msg `
		-Path $PSScriptRoot\..\chrupd.ps1
	#>
	. $PSScriptRoot\..\chrupd.ps1 | Out-Null
	$testRssFeed = "@{archMatch=True; hashFormatMatch=True; channelMatch=True; urlMatch=True; tagMatch=True; editorMatch=True; hashAlgo=sha1; hash=8fb1ede28391ad944059d318340017524117e01d; titleMatch=True; editor=Hibbiki; architecture=64-bit; channel=stable; version=91.0.4472.101; revision=870763; codecs=all audio/video codecs; date=2021-06-10; mini_installer.sync.exe_sha1=8fb1ede28391ad944059d318340017524117e01d; url=https://github.com/Hibbiki/chromium-win64/releases/download/v91.0.4472.101-r870763/mini_installer.sync.exe; virusTotalUrl=https://www.virustotal.com/gui/file/8fb1ede28391ad944059d318340017524117e01d/detection; chrome.sync.7z_sha1=bfb39c9e7bfb595ce134436aeb34d31053f342b2}"

}

Describe "Read-RssFeed" {
	It "parse cdata using 'htmlfile'" {
		if ($env:CI) {
			Read-RssFeed -rssFeed "https://raw.githubusercontent.com/mkorthof/chrupd/master/test/windows-64-bit" -cdataMethod "htmlfile" | Should -Be $testRssFeed | ConvertTo-Json
		} else {
			Read-RssFeed -rssFeed "file://$PSScriptRoot/windows-64-bit" -cdataMethod "htmlfile" | Should -Be $testRssFeed | ConvertTo-Json
		}
	}	
}