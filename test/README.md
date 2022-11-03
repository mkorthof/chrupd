# Tests

## PSScriptAnalyzer

- Runs also in CI
- <https://github.com/PowerShell/PSScriptAnalyzer>

## test.bat

- Run and check logs for strings (`-r`)
- Run PSScriptAnalyzer (`-p`)

## Pester

Using Pester on whole script instead of separate "\<Function\>.ps1" files.

Also, PSCustomObjects need to be converted to JSON for comparison

- Test 1 function: `Invoke-Pester .\test\Write-Msg.Tests.ps1`
- Test all functions: `Invoke-Pester`

Sources:

- <https://pester.dev/docs/quick-start>
- <https://jakubjares.com/2019/06/09/2019-07-testing-whole-scripts/>
- <https://www.powershellgallery.com/packages/ImportTestScript/1.0.1>

## Test data

- windows-64-bit (woollys)
- releases.json (github)
