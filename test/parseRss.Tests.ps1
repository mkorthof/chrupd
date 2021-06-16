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

<# TODO:
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
		hashFmtMatch = $False
	}
	$xml = [xml](Get-Content "windows-64-bit")
#>