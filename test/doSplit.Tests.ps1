BeforeAll {
    Push-Location
    Start-Transaction
    Set-Location ..
    Import-Script `
    -EntryPoint Write-Msg `
    -Path $PSScriptRoot/../chrupd.ps1
    Complete-Transaction
}

Describe "doSplit" {
    $val = 'config', 'script', 'head', 'hash'
    $test = doSplit $(Get-Content $PSScriptRoot/../chrupd.ps1)
    It "splits header and config from script content" -ForEach $val {
        #$test.Values | Should -Match ".*<# CONFIGURATION:.*"
        $test.Keys | Should -Contain $_
    }
}

AfterAll {
    Pop-Location
}
