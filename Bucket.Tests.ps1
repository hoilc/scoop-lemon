if (-not $env:SCOOP_HOME) { $env:SCOOP_HOME = Resolve-Path (scoop prefix scoop) }

# Don't install when not in CI
if (-not $env:CI) {
    Write-Host 'Skipping installation.' -ForegroundColor Yellow
    return
}

. "$env:SCOOP_HOME\lib\manifest.ps1" # Import for parse json function
. "$env:SCOOP_HOME\lib\json.ps1"
. "$env:SCOOP_HOME\test\Import-Bucket-Tests.ps1" # run tests from scoop core

function substitute_non_ascii_shortcuts($manifest, $app) {
    if ($manifest.shortcuts -and $manifest.shortcuts.Count -gt 0) {
        for ($i = 0; $i -lt $manifest.shortcuts.Count; $i++) {
            if ($manifest.shortcuts[$i] -is [array] -and $manifest.shortcuts[$i].Count -ge 2) {
                $shortcutName = $manifest.shortcuts[$i][1]
                if ($shortcutName -match "[^\x00-\x7F]") {
                    $manifest.shortcuts[$i][1] = "shortcut-{0}-{1}" -f $app, $i
                    Write-Host ("[Workaround] Substitute shortcut '{0}' with placeholder '{1}'" -f $shortcutName, $manifest.shortcuts[$i][1])
                }
            }
        }
    }

    if ($manifest.architecture) {
        foreach ($arch in $manifest.architecture.PSObject.Properties.Name) {
            if ($manifest.architecture.$arch.shortcuts -and $manifest.architecture.$arch.shortcuts.Count -gt 0) {
                for ($i = 0; $i -lt $manifest.architecture.$arch.shortcuts.Count; $i++) {
                    if ($manifest.architecture.$arch.shortcuts[$i] -is [array] -and $manifest.architecture.$arch.shortcuts[$i].Count -ge 2) {
                        $shortcutName = $manifest.architecture.$arch.shortcuts[$i][1]
                        if ($shortcutName -match "[^\x00-\x7F]") {
                            $manifest.architecture.$arch.shortcuts[$i][1] = "shortcut-{0}-{1}-{2}" -f $app, $arch, $i
                            Write-Host ("[Workaround] Substitute shortcut '{0}' with placeholder '{1}'" -f $shortcutName, $manifest.architecture.$arch.shortcuts[$i][1])
                        }
                    }
                }
            }
        }
    }
    return $manifest
}

# region Install changed manifests
function log() {
    param([String[]] $message = "============`r`n")

    Add-Content "./INSTALL.log" ($message -join "`r`n") -Encoding Ascii
}

function logError() {
    param([String[]] $message = "============`r`n")

    Add-Content "./ERROR.log" ($message -join "`r`n") -Encoding Ascii
}

function install() {
    param(
        [String] $manifest,
        [ValidateSet('32bit', '64bit', 'arm64', 'URL')]
        [String] $architecture
    )

    $command = "scoop install $manifest --independent"
    if ($architecture -ne 'URL') {
        $command += " --arch $architecture"
    }

    log "Command: $command"

    $result = @(Invoke-Expression "$command *>&1")
    $exit = $LASTEXITCODE

    log
    log "Manifest: $manifest"
    log "Arch: $architecture"
    log $result
    log

    if ($exit -ne 0) {
        logError "## $command"
        logError '```'
        logError $result
        logError '```'
    }

    return $exit
}

function uninstall($noExt) {
    $log = @(scoop uninstall $noExt *>&1)

    if ($LASTEXITCODE -eq 0) {
        log
        log 'Uninstallation'
        log $log
        log "$noExt`: Uninstall DONE"
        log
    } else {
        logError "## scoop uninstall $noExt"
        logError '```'
        logError $result
        logError '```'
    }
}

Describe 'Changed manifests installation' {
    # Duplicate check when test is manually executed.
    if (-not $env:CI) { # Do not install on powershell core
        Write-Host 'This test should run only in CI environment and on Powershell 5.' -ForegroundColor Yellow
        return
    }

    if ($PSVersionTable.PSVersion.Major -ge 6) {
        Write-Host 'Skipping installation in PWSH, to not install twice.' -ForegroundColor Yellow
        return
    }

    $env:PATH = "$env:PATH;$env:SCOOP\shims"
    . "$env:SCOOP_HOME\bin\refresh.ps1"
    $INSTALL_FILES_EXCLUSIONS = @(
        '.vscode',
        'TODO',
        'KMS',
        'E2B',
        'unlocker',
        'Spotify',
        'TrainerManager',
        'deprecated'
    ) -join '|'
    $INSTALL_FILES_EXCLUSIONS = ".*($INSTALL_FILES_EXCLUSIONS).*"

    New-Item 'INSTALL.log', 'ERROR.log' -Type File -Force
    if ($env:GITHUB_PULL_REQUEST_BASE_SHA) {
        Write-Host "[PR] Get changed file from $env:GITHUB_PULL_REQUEST_BASE_SHA to recent"
        $changedFiles = Get-GitChangedFile -LeftRevision $env:GITHUB_PULL_REQUEST_BASE_SHA -Include '*.json'
    } elseif ($env:GITHUB_PUSH_EVENT_BEFORE_SHA -and $env:GITHUB_PUSH_EVENT_AFTER_SHA -and ($env:GITHUB_PUSH_EVENT_BEFORE_SHA -ne "0000000000000000000000000000000000000000"))
    {
        Write-Host "[Push] Get changed file from $env:GITHUB_PUSH_EVENT_BEFORE_SHA to $env:GITHUB_PUSH_EVENT_AFTER_SHA"
        $changedFiles = Get-GitChangedFile -LeftRevision $env:GITHUB_PUSH_EVENT_BEFORE_SHA -RightRevision $env:GITHUB_PUSH_EVENT_AFTER_SHA -Include '*.json'
    } else {
        Write-Host "Get changed file in $env:GITHUB_SHA"
        $changedFiles = Get-GitChangedFile -Commit $env:GITHUB_SHA -Include '*.json'
    }
    $changedFiles = $changedFiles | Where-Object { ($_ -inotmatch $INSTALL_FILES_EXCLUSIONS) }

    if ($changedFiles.Count -gt 0) {
        scoop config lastupdate (([System.DateTime]::Now).ToString('o')) # Disable scoop auto update when installing manifests
        Write-Host "Ensuring helpers..."
        scoop install -g --no-cache sudo 7zip innounp dark lessmsi zstd # Install default apps for manifest manipultion / installation
        $7zipPath = Get-HelperPath -Helper 7zip
        Write-Host "7zip path: $7zipPath"

        foreach ($file in $changedFiles) {
            # Skip deleted manifests
            if (-not (Test-Path $file)) { continue }

            $man = Split-Path $file -Leaf
            $noExt = $man.Split('.')[0]
            $toInstall = ".\bucket\$man"

            $64 = '64bit'
            $32 = '32bit'
            $arm64 = 'arm64'
            $URL = 'URL'

            Context $man {
                # TODO: YAML
                $json = parse_json $file

                if ((Get-Content -Path $file -Encoding UTF8) -match "[^\x00-\x7F]") {
                    $newContent = substitute_non_ascii_shortcuts $json $noExt | ConvertToPrettyJson
                    [System.IO.File]::WriteAllLines($file, $newContent)
                }

                if ($json.architecture) {
                    if ($json.architecture.$64) {
                        It $64 {
                            install $toInstall $64 | Should -Be 0
                        }
                        uninstall $noExt
                    }
                    if ($json.architecture.$32) {
                        It $32 {
                            install $toInstall $32 | Should -Be 0
                        }
                        uninstall $noExt
                    }
                    if ($json.architecture.$arm64) {
                        It $arm64 {
                            install $toInstall $arm64 | Should -Be 0
                        }
                        uninstall $noExt
                    }
                } else {
                    It $URL { install $toInstall $URL | Should -Be 0 }
                }
            }
        }
    }
}
# endregion Install changed manifests
