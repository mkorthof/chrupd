BeforeAll {
	. $PSScriptRoot\..\chrupd.ps1 | Out-Null
}

Describe "Get-SevenZip" {
	It "locates or downloads 7z binary" {
		if ($env:CI) {
			Get-SevenZip Should -Be "7za.exe"
		} else {
			Get-SevenZip Should -Be "C:\Program Files\7-Zip\7z.exe"
		}
	}	
}