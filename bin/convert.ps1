param ([String] $Dir = "$PSScriptRoot\..\bucket")

if (-not $env:SCOOP_HOME) { $env:SCOOP_HOME = Resolve-Path (scoop prefix scoop) }

# Import-Module (Resolve-Path "$env:SCOOP_HOME\supporting\yaml\bin\powershell-yaml.psm1")
. "$env:SCOOP_HOME\lib\manifest.ps1"

$Dir = Resolve-Path $Dir
$files = (Get-ChildItem $Dir '*.json')

foreach ($file in $files) {
    $content = Get-Manifest $file.FullName
    $newfile = "$Dir\$($file.BaseName).yml"

    # Move to keep history
    git mv $file.Fullname $newfile

    Set-Manifet $newfile $content
}
