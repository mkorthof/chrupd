BeforeAll {
    <#
    Import-Script `
		-EntryPoint Write-Msg `
		-Path $PSScriptRoot/../chrupd.ps1 
    #>
    . $PSScriptRoot\..\chrupd.ps1 -cAutoUp 0
    if ($env:CI) {
        $testVer = $(@{osFullName="`"Windows Server 2016`" (10.0, Server)"; tsModeName="Normal"; tsMode=1;} | ConvertTo-Json)
    } else {
        $testVer = $(@{osFullName="`"Windows 10`" (10.0, Workstation)"; tsModeName="Normal"; tsMode=1;} | ConvertTo-Json)
    }
}

<# TODO: mocks
    ([System.Environment]::OSVersion).Version.Major
    (Get-CIMInstance Win32_OperatingSystem).ProductType
#>

Describe "Get-WinVer" {
    It "Get Windows Version and supported Task Scheduler Mode" {
        Get-WinVer -osInfo $osObj -tsModeNum 1 | ConvertTo-Json | Should -Be $testVer
    }
}
