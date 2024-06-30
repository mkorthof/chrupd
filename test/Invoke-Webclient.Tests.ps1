BeforeAll {
	. $PSScriptRoot\..\chrupd.ps1 | Out-Null
}

Describe "Invoke-WebClient" {
	It "downloads file or text" {
		Invoke-WebClient "http://example.org" pester_tmp.out
		"$PSScriptRoot\..\pester_tmp.out" | Should -FileContentMatchMultiline "Example Domain"
	}	
}

AfterAll {
	if (Test-Path $PSScriptRoot\..\pester_tmp.out) {
		Remove-Item $PSScriptRoot\..\pester_tmp.out
	}
}