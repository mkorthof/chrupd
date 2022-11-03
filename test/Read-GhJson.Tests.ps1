BeforeAll {
    <#
    Import-Script `
		-EntryPoint Write-Msg `
		-Path $PSScriptRoot/../chrupd.ps1 
    #>
    
    . $PSScriptRoot\..\chrupd.ps1 -cAutoUp 0
}

Describe "Read-GhJson" {
    It "Extract JSON values from GitHub repos api" {
        Read-GhJson -jsonUrl "file://$PSScriptRoot/releases.json" | Should -Be `
            "@{version=v107.0.5252.0-r0-AVX2; archMatch=True; hashFormatMatch=False; revision=; url=; channelMatch=False; urlMatch=False; editorMatch=False; virusTotalUrl=https://www.virustotal.com/gui/file/5e6b6cc3a051c2243d327488e31a9042b226a63e36abff492016abe81279ad03; date=2022-08-21; hashAlgo=SHA1; hash=; titleMatch=True}"
    }
}
