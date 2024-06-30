BeforeAll {
	<#
    Import-Script `
		-EntryPoint Write-Msg `
		-Path $PSScriptRoot/../chrupd.ps1 
	#>
	. $PSScriptRoot\..\chrupd.ps1 | Out-Null
	$tsMode = 1
	$shTask = 1
	$crTask = 1
	
}

Describe "shTask" {
    It "show task" {
		$scriptName | Should -Be "Simple Chromium Updater"
		$scriptCmd | Should -Be "chrupd.ps1"
		$taskMsg.notfound | Should -Be "Scheduled Task not found."
    }
}

Describe "crTask" {
    It "create task" {
		"$($taskMsg.create -f "$scriptName")" | Should -Be "Creating Daily Task `"Simple Chromium Updater`" in Task Scheduler..." 
	}
}
