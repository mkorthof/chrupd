BeforeAll {
    <#
    Import-Script `
        -EntryPoint Write-Msg `
        -Path $PSScriptRoot/../chrupd.ps1
    #>
    . $PSScriptRoot/../chrupd.ps1
    $testSplit = Split-Script $(Get-Content $PSScriptRoot/../chrupd.ps1)
    #throw "DEBUG: test -> keys: $($test.Keys)"
    #throw "DEBUG: test -> $test head=$($test.head)"
    #throw "DEBUG: script=$($test.script.Length) lines test=$test type=$($test.gettype()) `r`n    $($test.config -Match ".*<# CONFIGURATION:.*")"
}

Describe "Split-Script" {
    It "splits 'header' and 'config' from script content" {
        ForEach ($v in 'config', 'script', 'head', 'hash') {  
            $testSplit.Keys | Should -Contain $v
        }
        $testSplit.config | Select-Object -First 1 | Should -Match "<# CONFIGURATION:? \s+ #>"
        $testSplit.config | Select-Object -Last 1 | Should -Match "<# END OF CONFIGURATION ?[#-]+ ?#>"
    }
}
