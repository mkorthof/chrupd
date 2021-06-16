#function f () {}
#New-Alias -Name Write-Msg -Value f
#. $PSScriptRoot/../chrupd.ps1 
#Remove-Alias -Name Write-Msg
#Remove-Item "function:/f"

BeforeAll {
    function Write-Host($a) {
        Write-Output $a
    }
    Push-Location
    Start-Transaction
    Set-Location ..
    Import-Script `
    -EntryPoint Write-Msg `
    -Path $PSScriptRoot\..\chrupd.ps1
    Complete-Transaction
}

Describe "Write-Msg" {
    It "writes messages" {
        #Write-Msg "" | Should -Be $null
        Write-Msg "test" | Should -Be "test"
    }
}

AfterAll {
    Pop-Location
}
