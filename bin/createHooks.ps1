$HOOKS_FOLD = Resolve-Path "$PSScriptRoot\..\.git\hooks"

# Exit when hooks folder does not exists for some reason
if (-not (Test-Path $HOOKS_FOLD -Type Container)){
    Write-Host 'Folder' $HOOKS_FOLD 'Does not Exists. Exiting' -ForegroundColor Red
    exit 1
}

$HOOKS = @{
    'PRE-COMMIT' = @(
        '#!/bin/sh',
        '',
        "powershell.exe -File '$PSScriptRoot\test.ps1'"
    );
}

$HOOKS.Keys | ForEach-Object { Set-Content "$HOOKS_FOLD\$_" ($HOOKS.Item($_) -join "`n") -Encoding Ascii }
