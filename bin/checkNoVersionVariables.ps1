param(
    [Parameter(Mandatory=$false)]
    [string]$AppPath = "bucket",
    [Parameter(Mandatory=$false)]
    [string]$StartTime,
    [Parameter(Mandatory=$false)]
    [string]$EndTime,
    [Parameter(Mandatory=$false)]
    [string[]]$Blacklist
)

if ($env:GITHUB_EVENT_NAME -eq "workflow_dispatch") {
    Write-Output "Skipping time window check for manually triggered workflow"
} elseif ($StartTime -or $EndTime) {
    if (-not $StartTime -or -not $EndTime) {
        Write-Error "Both -StartTime and -EndTime must be provided together or not at all"
        exit 1
    }

    try {
        if (-not ($StartTime -match '^\d{2}:\d{2}$')) {
            Write-Error "Start time format invalid. Expected format: HH:mm"
            exit 1
        }

        if (-not ($EndTime -match '^\d{2}:\d{2}$')) {
            Write-Error "End time format invalid. Expected format: HH:mm"
            exit 1
        }

        $currentTime = (Get-Date).ToUniversalTime().ToString("HH:mm")
        $currentHour = [int]$currentTime.Split(':')[0]
        $currentMinute = [int]$currentTime.Split(':')[1]
        $currentTimeSpan = New-TimeSpan -Hours $currentHour -Minutes $currentMinute

        $startHour = [int]$StartTime.Split(':')[0]
        $startMinute = [int]$StartTime.Split(':')[1]
        $startSpan = New-TimeSpan -Hours $startHour -Minutes $startMinute

        $endHour = [int]$EndTime.Split(':')[0]
        $endMinute = [int]$EndTime.Split(':')[1]
        $endSpan = New-TimeSpan -Hours $endHour -Minutes $endMinute

        Write-Output "Allowed time range (UTC): $StartTime - $EndTime, Current time: $currentTime"

        if ($startSpan -le $endSpan) {
            if (-not ($currentTimeSpan -ge $startSpan -and $currentTimeSpan -le $endSpan)) {
                Write-Output "Skipping check manifests without version variables, not in time window."
                if ($env:GITHUB_OUTPUT) {
                    Add-Content -Path $env:GITHUB_OUTPUT -Value "manifestsWithoutVersion="
                }
                exit 0
            }
        } else {
            if (-not ($currentTimeSpan -ge $startSpan -or $currentTimeSpan -le $endSpan)) {
                Write-Output "Skipping check manifests without version variables, not in time window."
                if ($env:GITHUB_OUTPUT) {
                    Add-Content -Path $env:GITHUB_OUTPUT -Value "manifestsWithoutVersion="
                }
                exit 0
            }
        }
    } catch {
        Write-Error "Error in time window check: $_"
        exit 1
    }
}

if ($Blacklist) {
    $blacklistItems = $Blacklist -split ',' | ForEach-Object { $_.Trim() }
}

$manifestFiles = Get-ChildItem -Path $AppPath -Filter *.json | Select-Object -ExpandProperty FullName

$manifestsWithoutVersion = @()

foreach ($manifestFile in $manifestFiles) {
    $manifestContentString = Get-Content -Path $manifestFile -Encoding UTF8
    $manifestContent = $manifestContentString | ConvertFrom-Json

    if ($manifestContent.autoupdate) {
        $hasVersionVar = $false

        if ($manifestContent.autoupdate.url -and $manifestContent.autoupdate.url -match '\$') {
            $hasVersionVar = $true
        }

        if ($manifestContent.autoupdate.architecture) {
            $archs = @('32bit', '64bit', 'arm64')
            foreach ($arch in $archs) {
                if ($manifestContent.autoupdate.architecture.$arch -and $manifestContent.autoupdate.architecture.$arch.url -match '\$') {
                    $hasVersionVar = $true
                    break
                }
            }
        }

        $matchCargoQuickInstall = ($manifestContentString -match 'cargo-bins/cargo-quickinstall')

        if ((-not $hasVersionVar) -or $matchCargoQuickInstall) {
            $manifestName = Split-Path -Path $manifestFile -Leaf
            $manifestName = [System.IO.Path]::GetFileNameWithoutExtension($manifestName)

            if ($blacklistItems -and $blacklistItems -contains $manifestName) {
                continue
            }

            $manifestsWithoutVersion += $manifestName
        }
    }
}

$manifestsWithoutVersion = $manifestsWithoutVersion | Sort-Object | Get-Unique

if ($manifestsWithoutVersion.Count -gt 0) {
    Write-Output "The following $($manifestsWithoutVersion.Count) manifests do not have a version variable:"
    $manifestsWithoutVersion | ForEach-Object { Write-Output "$_" }

    $outputValue = $manifestsWithoutVersion -join ","
    if ($env:GITHUB_OUTPUT) {
        Add-Content -Path $env:GITHUB_OUTPUT -Value "manifestsWithoutVersion=$outputValue"
    }
} else {
    Write-Output "No manifests without version variables found."

    if ($env:GITHUB_OUTPUT) {
        Add-Content -Path $env:GITHUB_OUTPUT -Value "manifestsWithoutVersion="
    }
}
