BeforeAll {
    <#
    Import-Script `
		-EntryPoint Write-Msg `
		-Path $PSScriptRoot/../chrupd.ps1
    #>
    
    . $PSScriptRoot\..\chrupd.ps1 -cAutoUp 0
    $testGhJson = "@{version=v124.0.6351.0-r1270729-win64-avx; archMatch=True; hashFormatMatch=False; revision=; url=; channelMatch=False; urlMatch=False; editorMatch=False; virusTotalUrl=; date=2024-03-11; hashAlgo=SHA1; hash=; titleMatch=True}"
}

Describe "Read-GhJson" {
    It "Extract JSON values from GitHub repos api" {
        if ($env:CI) {
            Read-GhJson -jsonUrl "https://raw.githubusercontent.com/mkorthof/chrupd/master/test/releases-2.json" | Should -Be $testGhJson | ConvertTo-Json
        } else {
            Read-GhJson -jsonUrl "file://$PSScriptRoot/releases-2.json" | Should -Be $testGhJson | ConvertTo-Json
        }
    }
}
