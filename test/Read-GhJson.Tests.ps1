BeforeAll {
    <#
    Import-Script `
        -EntryPoint Write-Msg `
        -Path $PSScriptRoot/../chrupd.ps1
    #>
    
    . $PSScriptRoot\..\chrupd.ps1 -cAutoUp 0
}

Describe "Read-GhJson" {
    $testGhJson = @(
        @{
            itemName = 'justclueless';
            expectedResult = "@{version=v107.0.5252.0-r0-AVX2; archMatch=True; hashFormatMatch=True; revision=; url=https://github.com/justclueless/chromium-win64/releases/download/v107.0.5252.0-r0-AVX2/mini_installer.exe; channelMatch=False; urlMatch=True; tagMatch=True; editorMatch=True; virusTotalUrl=https://www.virustotal.com/gui/file/5e6b6cc3a051c2243d327488e31a9042b226a63e36abff492016abe81279ad03; date=2022-08-21; hashAlgo=SHA1; hash=a6377656835fcb11fb756c9442ca08b95843f31e; titleMatch=True}";
         }
        @{
           itemName = 'RobRich';
           expectedResult = "@{version=v124.0.6351.0-r1270729-win64-avx; archMatch=True; hashFormatMatch=True; revision=; url=https://github.com/RobRich999/Chromium_Clang/releases/download/v124.0.6351.0-r1270729-win64-avx/mini_installer.exe; channelMatch=False; urlMatch=True; tagMatch=True; editorMatch=True; virusTotalUrl=; date=2024-03-11; hashAlgo=SHA1; hash=bf71032fd51b807c5339143efe29362e1d6b45cb; titleMatch=True}";
        }
        # ...
    )
    It "Extract JSON values from GitHub repos api" -ForEach $testGhJson {
        $name = $itemName
        if ($env:CI) {
            Read-GhJson -jsonUrl "https://raw.githubusercontent.com/mkorthof/chrupd/master/test/releases-$itemName.json" | Should -Be $expectedResult | ConvertTo-Json
        } else {
            Read-GhJson -jsonUrl "file://$PSScriptRoot/releases-$itemName.json" | Should -Be $expectedResult | ConvertTo-Json
        }
    }
}