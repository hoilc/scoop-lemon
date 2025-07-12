if (-not $env:SCOOP_HOME) { $env:SCOOP_HOME = Resolve-Path (scoop prefix scoop) }

# Don't install when not in CI
if (-not $env:CI) {
    Write-Host 'Skipping installation.' -ForegroundColor Yellow
    return
}

. "$env:SCOOP_HOME\lib\manifest.ps1" # Import for parse json function
. "$env:SCOOP_HOME\test\Import-Bucket-Tests.ps1" # run tests from scoop core

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

    $command = "scoop install $manifest --no-cache --independent"
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

    if ($LASTEXITCODE -ne 0) {
        logError
        logError "## $command"
        logError '```'
        logError $result
        logError '```'
        logError
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
    }

    if ($LASTEXITCODE -ne 0) {
        logError
        logError "## scoop uninstall $noExt"
        logError '```'
        logError $result
        logError '```'
        logError
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

    New-Item 'INSTALL.log' -Type File -Force
    New-Item 'ERROR.log' -Type File -Force
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
        log "Ensuring helpers..."
        scoop install -g sudo 7zip innounp dark lessmsi # Install default apps for manifest manipultion / installation
        $7zipPath = Get-HelperPath -Helper 7zip
        log "7zip path: $7zipPath"

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
