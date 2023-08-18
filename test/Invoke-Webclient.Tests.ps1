BeforeAll {
	. $PSScriptRoot\..\chrupd.ps1 | Out-Null
}

Describe "Invoke-WebClient" {
	It "downloads file or text" {
		Invoke-WebClient "http://example.org" Should -Match "Example Domain"
	}	
}