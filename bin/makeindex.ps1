#!/usr/bin/env pwsh
# -*- coding: utf-8 -*-
<#
.SYNOPSIS
    Generate index table for Scoop bucket applications
.DESCRIPTION
    This script reads JSON files from the bucket directory and generates a Markdown table
    with application information including name, version, and description.
    Converted from makeindex.py
.PARAMETER Specs
    File patterns to match (default: bucket/*.json)
#>

param(
    [string[]]$Specs = @("bucket/*.json")
)

function Get-Url {
    param($JsonObject)

    if ($JsonObject.checkver -and $JsonObject.checkver.url) {
        return $JsonObject.checkver.url
    }
    if ($JsonObject.homepage) {
        return $JsonObject.homepage
    }
    return ''
}

function Get-Version {
    param($JsonObject)

    $version = $JsonObject.version
    $url = Get-Url $JsonObject

    if (-not $JsonObject.checkver) {
        $version = "<i>$version</i>"
    }

    if ($url -eq '') {
        return $version
    }

    return "[$version]($url)"
}

function Main {
    $markdown = 'README.md'
    Write-Host "Reading $markdown"

    if (-not (Test-Path $markdown)) {
        Write-Error "README.md not found"
        exit 1
    }

    $lines = Get-Content $markdown -Encoding UTF8

    # If no specs provided, use default
    if ($Specs.Count -eq 0) {
        $Specs = @('bucket/*.json')
    }

    $keys = @('checkver', 'description', 'homepage', 'version')
    $rows = @{}

    # Get git tracked files
    try {
        $gitFiles = git ls-files | Where-Object { $_ -match '\.json$' }
    }
    catch {
        Write-Error "Failed to get git files: $_"
        exit 1
    }

    foreach ($file in $gitFiles) {
        # Skip WIP files
        if ($file -match 'wip/') {
            continue
        }

        # Check if file matches any spec pattern
        $accept = $false
        foreach ($spec in $Specs) {
            if ($file -like $spec) {
                $accept = $true
                break
            }
        }

        if (-not $accept) {
            continue
        }

        Write-Host "Processing file: $file"

        try {
            $jsonContent = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
            $name = [System.IO.Path]::GetFileNameWithoutExtension($file)

            # Skip files starting with _ or schema
            if ($name -match '^_' -or $name -match '^schema') {
                continue
            }

            $row = @{}
            foreach ($key in $keys) {
                if ($jsonContent.$key) {
                    $val = $jsonContent.$key
                    if ($val -is [string]) {
                        $val = $val.Trim()
                    }
                    if ($key -eq 'version') {
                        $val = Get-Version $jsonContent
                    }
                    $row[$key] = $val
                }
                else {
                    $row[$key] = ''
                }
            }
            $rows[$name] = $row
        }
        catch {
            Write-Warning "Failed to process $file : $_"
            continue
        }
    }

    # Create table
    $table = @(
        '<!-- The following table was inserted by makeindex.ps1 -->',
        '<!-- Your edits will be lost the next time makeindex.ps1 is run -->',
        '|Name|Version|Description|',
        '|----|-------|-----------|'
    )

    # Sort and add rows
    $sortedKeys = $rows.Keys | Sort-Object
    foreach ($name in $sortedKeys) {
        $row = $rows[$name]
        $homepage = if ($row['homepage']) { $row['homepage'] } else { '' }
        $version = if ($row['version']) { $row['version'] } else { '' }
        $description = if ($row['description']) { $row['description'] } else { '' }

        $table += "|[$name]($homepage)|$version|$description|"
    }

    # Process README.md
    $out = @()
    $found = $false

    foreach ($line in $lines) {
        $line = $line.Trim()

        if ($found) {
            if ($line -match '^\s*<!--\s+</apps>\s+-->') {
                $found = $false
            }
            else {
                continue
            }
        }

        if ($line -match '^\s*<!--\s+<apps>\s+-->') {
            $found = $true
            $out += $line
            $out += $table
            continue
        }

        $out += $line
    }

    Write-Host "Writing $markdown"

    # Write to temporary file with CRLF line endings, no BOM
    $tempFile = "$markdown.tmp"
    $data = ($out -join "`r`n") + "`r`n"

    # Use .NET StreamWriter to write UTF-8 without BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    $writer = New-Object System.IO.StreamWriter($tempFile, $false, $utf8NoBom)
    $writer.Write($data)
    $writer.Close()

    # Backup and replace
    $backupFile = "$markdown.bak"
    if (Test-Path $backupFile) {
        Remove-Item $backupFile -Force
    }

    if (Test-Path $markdown) {
        Rename-Item $markdown $backupFile
    }
    Rename-Item $tempFile $markdown

    Write-Host "Index generation completed successfully"
}

# Run main function
Main
exit 0
