param(
    [Parameter(Mandatory=$true)]
    [string]$filePath
)

$insertCode = @'
if ($env:BHBuildSystem -eq 'GitHub Actions') {
    $splat.OutputFile = "$env:GITHUB_WORKSPACE\TestResults.xml"
    $splat.OutputFormat = 'JUnitXml'
}
'@

if (-not (Test-Path $filePath)) {
    Write-Error "File not found: $filePath"
    exit 1
}

(Get-Content $filePath) | ForEach-Object {
    $_
    if ($_ -match '# GitHub Actions') {
        $insertCode
    }
} | Set-Content $filePath -Encoding UTF8
