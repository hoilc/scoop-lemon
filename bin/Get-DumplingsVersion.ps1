<#
.SYNOPSIS
    Get the latest version of specified applications from Dumplings project.

.DESCRIPTION
    This script fetches the latest version information from the Dumplings project
    (https://github.com/SpecterShell/Dumplings) by reading the State.yaml files
    from /Tasks/<app>/State.yaml paths. It supports both GitHub API and
    raw.githubusercontent.com methods for content retrieval.

.PARAMETER AppName
    The name of the application to get version for (e.g., "PIKCLOUD.PikPak").

.PARAMETER UseRawContent
    Switch to use raw.githubusercontent.com instead of GitHub API.

.PARAMETER OutputFormat
    Output format: "Version" (default), "Json", "Original", "Object".

.PARAMETER PreferRealVersion
    When OutputFormat is "Version", prefer RealVersion over Version if available.

.EXAMPLE
    .\Get-DumplingsVersion.ps1 -AppName "PIKCLOUD.PikPak"

.EXAMPLE
    .\Get-DumplingsVersion.ps1 -AppName "PIKCLOUD.PikPak" -UseRawContent -OutputFormat Json

.EXAMPLE
    .\Get-DumplingsVersion.ps1 -AppName "PIKCLOUD.PikPak" -Verbose
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AppName,

    [switch]$UseRawContent,

    [ValidateSet("Version", "Json", "Original", "Object")]
    [string]$OutputFormat = "Version",

    [switch]$PreferRealVersion
)

# GitHub repository information
$Owner = "SpecterShell"
$Repo = "Dumplings"
$Branch = "main"
$FilePath = "Tasks/$AppName/State.yaml"

# Function to write verbose messages
function Write-VerboseMessage {
    param([string]$Message)
    if ($VerbosePreference -ne 'SilentlyContinue') {
        Write-Verbose $Message
    }
}

# Function to create web request with proxy and authentication
function New-WebRequest {
    param(
        [string]$Uri,
        [hashtable]$Headers = @{}
    )

    try {
        # Create web request
        $request = [System.Net.WebRequest]::Create($Uri)
        $request.Method = "GET"
        $request.UserAgent = "PowerShell/Get-DumplingsVersion"

        # Add headers
        foreach ($header in $Headers.GetEnumerator()) {
            if ($header.Key -eq "Authorization") {
                $request.Headers.Add($header.Key, $header.Value)
            } else {
                $request.Headers.Add($header.Key, $header.Value)
            }
        }

        # Configure proxy if environment variables are set
        $httpProxy = $env:http_proxy
        $httpsProxy = $env:https_proxy

        if ($httpsProxy) {
            Write-VerboseMessage "Using HTTPS proxy: $httpsProxy"
            $request.Proxy = New-Object System.Net.WebProxy($httpsProxy)
        } elseif ($httpProxy) {
            Write-VerboseMessage "Using HTTP proxy: $httpProxy"
            $request.Proxy = New-Object System.Net.WebProxy($httpProxy)
        }

        return $request
    } catch {
        throw "Failed to create web request: $_"
    }
}

# Function to get content via GitHub API
function Get-ContentViaAPI {
    param([string]$AppName)

    $apiUrl = "https://api.github.com/repos/$Owner/$Repo/contents/$FilePath"
    Write-VerboseMessage "Using GitHub API: $apiUrl"

    $headers = @{
        "Accept" = "application/vnd.github.v3+json"
    }

    # Add authentication if GH_TOKEN is available
    if ($env:GH_TOKEN) {
        Write-VerboseMessage "Using GitHub token for authentication"
        $headers["Authorization"] = "token $env:GH_TOKEN"
    }

    try {
        $request = New-WebRequest -Uri $apiUrl -Headers $headers
        $response = $request.GetResponse()
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        $jsonContent = $reader.ReadToEnd()
        $reader.Close()
        $response.Close()

        $apiResponse = $jsonContent | ConvertFrom-Json

        if ($apiResponse.type -eq "symlink") {
            Write-VerboseMessage "Detected symlink, target: $($apiResponse.target)"
            # For symlinks, GitHub API returns the actual content directly
            $content = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($apiResponse.content))
        } elseif ($apiResponse.type -eq "file") {
            Write-VerboseMessage "Detected regular file"
            $content = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($apiResponse.content))
        } else {
            throw "Unexpected content type: $($apiResponse.type)"
        }

        return $content
    } catch {
        throw "Failed to get content via GitHub API: $_"
    }
}

# Function to get content via raw.githubusercontent.com
function Get-ContentViaRaw {
    param([string]$AppName)

    $rawUrl = "https://raw.githubusercontent.com/$Owner/$Repo/$Branch/$FilePath"
    Write-VerboseMessage "Using raw content URL: $rawUrl"

    try {
        $request = New-WebRequest -Uri $rawUrl
        $response = $request.GetResponse()
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        $content = $reader.ReadToEnd()
        $reader.Close()
        $response.Close()

        # Check if this is a symlink (raw.githubusercontent.com returns target path for symlinks)
        if ($content -match '^\.\./' -or $content -match '^[^:\n]+$' -and $content.Length -lt 100) {
            Write-VerboseMessage "Detected symlink, target path: $content"
            $targetPath = $content.Trim()

            # Resolve relative path
            $basePath = "Tasks/$AppName"
            $resolvedPath = Join-Path $basePath $targetPath
            $resolvedPath = $resolvedPath -replace '\\', '/'

            # Get the actual file content
            $targetUrl = "https://raw.githubusercontent.com/$Owner/$Repo/$Branch/$resolvedPath"
            Write-VerboseMessage "Fetching target file: $targetUrl"

            $targetRequest = New-WebRequest -Uri $targetUrl
            $targetResponse = $targetRequest.GetResponse()
            $targetReader = New-Object System.IO.StreamReader($targetResponse.GetResponseStream())
            $content = $targetReader.ReadToEnd()
            $targetReader.Close()
            $targetResponse.Close()
        }

        return $content
    } catch {
        throw "Failed to get content via raw URL: $_"
    }
}

# Function to parse YAML content and extract version
function Get-VersionFromYaml {
    param(
        [string]$YamlContent,
        [bool]$PreferReal = $false
    )

    try {
        $lines = $YamlContent -split "`n"
        $version = $null
        $realVersion = $null

        foreach ($line in $lines) {
            $line = $line.Trim()
            if ($line -match '^-?\s*Version:\s*(.+)$') {
                $version = $matches[1].Trim('"', "'")
            } elseif ($line -match '^-?\s*RealVersion:\s*(.+)$') {
                $realVersion = $matches[1].Trim('"', "'")
            }
        }

        # Return preferred version
        if ($PreferReal -and $realVersion) {
            return $realVersion
        } elseif ($version) {
            return $version
        } else {
            throw "Version field not found in YAML content"
        }
    } catch {
        throw "Failed to parse version from YAML: $_"
    }
}

# Function to parse YAML content into object
function ConvertFrom-SimpleYaml {
    param([string]$YamlContent)

    $result = @{}
    $lines = $YamlContent -split "`n"

    foreach ($line in $lines) {
        $line = $line.Trim()
        if ($line -and !$line.StartsWith("#")) {
            if ($line -match '^-?\s*([^:]+):\s*(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim('"', "'")

                # Skip empty values and specific unwanted fields
                if ($value -and $key -ne "Locale") {
                    $result[$key] = $value
                }
            }
        }
    }

    return $result
}

# Main execution
try {
    Write-VerboseMessage "Checking version from Dumplings: $AppName"
    Write-VerboseMessage "Output format: $OutputFormat"
    Write-VerboseMessage "Use raw content: $UseRawContent"

    # Get content based on method selection
    if ($UseRawContent) {
        $yamlContent = Get-ContentViaRaw -AppName $AppName
    } else {
        $yamlContent = Get-ContentViaAPI -AppName $AppName
    }

    Write-VerboseMessage "Successfully retrieved YAML content"

    # Output based on format
    switch ($OutputFormat) {
        "Version" {
            $version = Get-VersionFromYaml -YamlContent $yamlContent -PreferReal $PreferRealVersion
            Write-VerboseMessage "Return content string: $version"
            Write-Output $version
        }
        "Json" {
            $yamlObject = ConvertFrom-SimpleYaml -YamlContent $yamlContent
            $yamlObject | ConvertTo-Json -Depth 10
        }
        "Original" {
            Write-Output $yamlContent
        }
        "Object" {
            $yamlObject = ConvertFrom-SimpleYaml -YamlContent $yamlContent
            Write-Output $yamlObject
        }
    }

    Write-VerboseMessage "Version retrieval completed successfully"

} catch {
    Write-Output "null"
    Write-Error "Error: $_"
    exit 1
}
