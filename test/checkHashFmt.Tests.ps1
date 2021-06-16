BeforeAll {
    Push-Location
    Start-Transaction
    Set-Location ..
    Import-Script `
    -EntryPoint Write-Msg `
    -Path $PSScriptRoot/../chrupd.ps1 
}

Describe "checkHashFmt" {
    $cdataObj = New-Object -Type PSObject -Property @{
		date         = $null
		hash         = $null
		hashAlgo     = $null
		url          = $null
		revision     = $null
		version      = $null
		virusTotal   = $null
		titleMatch   = $False
		editorMatch  = $False
		archMatch    = $False
		channelMatch = $False
		urlMatch     = $False
		hashFmtMatch = $True
	}
    It "validate hash format" {
        checkHashFmt($cdataObj) | Should -BeTrue
    }
}

AfterAll {
    Pop-Location
}
