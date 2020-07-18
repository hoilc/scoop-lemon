<#
.SYNOPSIS
    Execute Pester tests in repository root directory.
#>

$result = Invoke-Pester "$PSScriptRoot\..\Scoop-Bucket.Tests.Local.ps1" -PassThru

exit $result.FailedCount
