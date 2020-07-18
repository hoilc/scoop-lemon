$ROOT_DIRECTORY = Resolve-Path "$PSScriptRoot\.."
$BUCKET_DIRECTORY = Resolve-Path "$ROOT_DIRECTORY\bucket"

# . "$env:SCOOP_HOME\supporting\yml\powershell-yaml.psm1"

function Get-RecursiveFolder {
    $folders = @($ROOT_DIRECTORY)
    $folders += Get-ChildItem $ROOT_DIRECTORY -Directory | Where-Object { $_ -inotmatch '.vscode|bin|.github' }

    return Resolve-Path $folders
}
