# 新增的脚本内容
function Update-ScoopManifest {
    param(
        [Parameter(Mandatory=$false)]
        [string]$AppPath = "bucket",
        [Parameter(Mandatory=$false)]
        [string]$CheckverScript = "bin\checkver.ps1"
    )

    # 获取所有manifest文件
    $manifestFiles = Get-ChildItem -Path $AppPath -Filter *.json | Select-Object -ExpandProperty FullName

    foreach ($manifestFile in $manifestFiles) {
        # 读取manifest内容
        $manifestContent = Get-Content -Path $manifestFile -Raw | ConvertFrom-Json
        
        # 检查是否有autoupdate部分
        if ($manifestContent.autoupdate) {
            $hasVersionVar = $false
            
            # 检查顶层url是否包含$version或$match变量
            if ($manifestContent.autoupdate.url -and $manifestContent.autoupdate.url -match '\$') {
                $hasVersionVar = $true
            }
            
            # 检查architecture下的各个架构中的url是否包含$version或$match变量
            if ($manifestContent.autoupdate.architecture) {
                $archs = @('32bit', '64bit', 'arm64')
                foreach ($arch in $archs) {
                    if ($manifestContent.autoupdate.architecture.$arch -and $manifestContent.autoupdate.architecture.$arch.url -match '\$') {
                        $hasVersionVar = $true
                        break
                    }
                }
            }
            
            # 如果没有找到版本号变量，则执行强制更新
            if (-not $hasVersionVar) {
                Write-Host "Processing manifest: $manifestFile"
                
                # 执行checkver.ps1强制更新
                & $CheckverScript -Name (Split-Path -Path $manifestFile -LeafBase) -ForceUpdate
                
                # 检查是否有更新
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Update successful for $manifestFile"
                    # 提交commit
                    # git add $manifestFile
                    # git commit -m "Update $manifestFile with ForceUpdate"
                } else {
                    Write-Host "No update for $manifestFile"
                }
            }
        }
    }

    git status
}

# 调用函数更新所有需要强制更新的manifest
Update-ScoopManifest