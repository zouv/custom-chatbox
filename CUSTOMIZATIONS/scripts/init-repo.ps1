#!/usr/bin/env pwsh
<#
.SYNOPSIS
    初始化 chatbox 自定义开发仓库结构。
.DESCRIPTION
    用于在 clone chatbox 仓库后，一键配置 upstream remote、创建分支结构、
    初始化 CUSTOMIZATIONS 目录和追踪文件。
.PARAMETER UpstreamUrl
    上游仓库 URL
.PARAMETER BaseVersion
    基于的上游版本（tag 名），如 v1.22.3。留空则使用最新 tag。
#>

param(
    [string]$UpstreamUrl = "https://github.com/chatboxai/chatbox.git",
    [string]$BaseVersion = ""
)

$ErrorActionPreference = "Stop"

Write-Host "=== Chatbox 自定义仓库初始化 ===" -ForegroundColor Cyan

if (-not (Test-Path ".git")) {
    Write-Error "当前目录不是 git 仓库"
    exit 1
}

if (-not (Test-Path "package.json")) {
    Write-Error "当前目录下未找到 package.json"
    exit 1
}

# [1] 配置 upstream
Write-Host "`n[1/6] 配置 upstream remote..." -ForegroundColor Yellow
$existingUpstream = git remote get-url upstream 2>$null
if ($LASTEXITCODE -eq 0 -and $existingUpstream) {
    Write-Host "  upstream 已存在: $existingUpstream"
    if ($existingUpstream -ne $UpstreamUrl) {
        git remote set-url upstream $UpstreamUrl
        Write-Host "  已更新为: $UpstreamUrl"
    }
} else {
    git remote add upstream $UpstreamUrl
    Write-Host "  已添加 upstream: $UpstreamUrl"
}

# [2] Fetch 上游
Write-Host "`n[2/6] 获取上游信息..." -ForegroundColor Yellow
git fetch upstream --tags

if (-not $BaseVersion) {
    $BaseVersion = git tag -l "v*" --sort=-v:refname | Select-Object -First 1
    Write-Host "  使用最新 tag: $BaseVersion"
}

# [3] 创建 vendor 分支
Write-Host "`n[3/6] 创建 vendor 分支..." -ForegroundColor Yellow
if ($BaseVersion -match '^v(\d+)\.(\d+)\.') {
    $vendorBranch = "vendor/v$($Matches[1]).$($Matches[2]).x"
} else {
    $vendorBranch = "vendor/main"
}

$vendorExists = git rev-parse --verify "$vendorBranch" 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  $vendorBranch 已存在"
} else {
    git checkout -b $vendorBranch $BaseVersion
    Write-Host "  已创建 $vendorBranch (基于 $BaseVersion)"
}

# [4] 创建 custom/main
Write-Host "`n[4/6] 创建 custom/main 分支..." -ForegroundColor Yellow
$customExists = git rev-parse --verify "custom/main" 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  custom/main 已存在"
    git checkout custom/main
} else {
    git checkout -b custom/main $vendorBranch
    Write-Host "  已创建 custom/main"
}

# [5] 创建目录
Write-Host "`n[5/6] 创建目录结构..." -ForegroundColor Yellow
foreach ($d in @("CUSTOMIZATIONS/src", "CUSTOMIZATIONS/patches", "CUSTOMIZATIONS/scripts")) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        New-Item -ItemType File -Path "$d/.gitkeep" -Force | Out-Null
        Write-Host "  创建 $d/"
    }
}

# 拷贝脚本
$scriptSource = $PSScriptRoot
if ($scriptSource -and (Test-Path "$scriptSource/init-repo.ps1")) {
    if (-not (Test-Path "CUSTOMIZATIONS/scripts/init-repo.ps1")) {
        Copy-Item "$scriptSource/init-repo.ps1" "CUSTOMIZATIONS/scripts/init-repo.ps1"
    }
    if (-not (Test-Path "CUSTOMIZATIONS/scripts/sync-vendor.ps1") -and (Test-Path "$scriptSource/sync-vendor.ps1")) {
        Copy-Item "$scriptSource/sync-vendor.ps1" "CUSTOMIZATIONS/scripts/sync-vendor.ps1"
    }
    if (-not (Test-Path "CUSTOMIZATIONS/scripts/list-custom.ps1") -and (Test-Path "$scriptSource/list-custom.ps1")) {
        Copy-Item "$scriptSource/list-custom.ps1" "CUSTOMIZATIONS/scripts/list-custom.ps1"
    }
}

# [6] CUSTOMIZATIONS.md
Write-Host "`n[6/6] 初始化 CUSTOMIZATIONS.md..." -ForegroundColor Yellow
if (-not (Test-Path "CUSTOMIZATIONS.md")) {
    $templatePath = "$PSScriptRoot/../CUSTOMIZATIONS.md"
    if (Test-Path $templatePath) {
        Copy-Item $templatePath "CUSTOMIZATIONS.md"
    } elseif (Test-Path "CUSTOMIZATIONS/CUSTOMIZATIONS.template.md") {
        Copy-Item "CUSTOMIZATIONS/CUSTOMIZATIONS.template.md" "CUSTOMIZATIONS.md"
    } else {
        Write-Warning "未找到 CUSTOMIZATIONS.md 模板，请从 chatbox-starter 目录复制"
    }
}

if (Test-Path "CUSTOMIZATIONS.md") {
    $commitHash = git rev-parse $BaseVersion
    $today = Get-Date -Format "yyyy-MM-dd"
    
    $content = Get-Content "CUSTOMIZATIONS.md" -Raw -Encoding UTF8
    $content = [regex]::Replace($content, '(current_upstream_version:\s*")[^"]*(")', "`${1}$BaseVersion`${2}")
    $content = [regex]::Replace($content, '(current_upstream_commit:\s*")[^"]*(")', "`${1}$commitHash`${2}")
    $content = [regex]::Replace($content, '(vendor_branch:\s*")[^"]*(")', "`${1}$vendorBranch`${2}")
    $content = [regex]::Replace($content, '(last_merge_date:\s*")[^"]*(")', "`${1}$today`${2}")
    Set-Content "CUSTOMIZATIONS.md" -Value $content -Encoding UTF8
    Write-Host "  CUSTOMIZATIONS.md 元数据已更新"
}

Write-Host "`n=== 初始化完成 ===" -ForegroundColor Green
Write-Host "当前分支: $(git branch --show-current)"
Write-Host "Vendor 分支: $vendorBranch ($BaseVersion)"
Write-Host ""
Write-Host "下一步："
Write-Host "  - 在 custom/main 上开发，完成后用 chatbox-record-change 记录改动"
Write-Host "  - 合并上游版本时用 chatbox-merge-upstream"
Write-Host "  - 发布时用 chatbox-release"
