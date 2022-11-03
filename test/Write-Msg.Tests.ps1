<#
    To use whole script, alias and source functions.
    Code replaced by 'Import-Script' (ImportTestScript module)
        function f () {}
        New-Alias -Name Write-Msg -Value f
        . $PSScriptRoot/../chrupd.ps1 
        Remove-Alias -Name Write-Msg
        Remove-Item "function:/f"
#>

BeforeAll {
    function Write-Host($a) {
        Write-Output $a
    }
    <#
    Push-Location
    Start-Transaction
    Set-Location ..
    Import-Script `
        -EntryPoint Write-Msg `
        -Path $PSScriptRoot/../chrupd.ps1
    Complete-Transaction
    #>
    . $PSScriptRoot/../chrupd.ps1
}

Describe "Write-Msg" {
    It "Is a Helper function to format and output (debug) messages" {
        Write-Msg "test" | Should -Be "test"
    }
}

<#
AfterAll {
    Pop-Location
}
#>