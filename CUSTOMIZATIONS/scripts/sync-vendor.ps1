#!/usr/bin/env pwsh
<#
.SYNOPSIS
    快速同步 vendor 分支到指定上游版本。
.DESCRIPTION
    AI Agent 在合并上游前可以先用此脚本查看/同步 vendor 分支。
.PARAMETER Version
    目标版本（tag），如 v1.22.4。留空则同步到 upstream/main 最新。
.PARAMETER Push
    是否自动推送到 origin
#>

param(
    [string]$Version = "",
    [switch]$Push
)

$ErrorActionPreference = "Stop"

Write-Host "=== Vendor 分支同步 ===" -ForegroundColor Cyan

git fetch upstream --tags

if (-not $Version) {
    $Version = git tag -l "v*" --sort=-v:refname | Select-Object -First 1
    Write-Host "未指定版本，使用最新 tag: $Version"
}

if ($Version -match '^v(\d+)\.(\d+)\.') {
    $vendorBranch = "vendor/v$($Matches[1]).$($Matches[2]).x"
} else {
    $vendorBranch = "vendor/main"
}

Write-Host "目标版本: $Version"
Write-Host "Vendor 分支: $vendorBranch"

$currentBranch = git branch --show-current
$vendorExists = git rev-parse --verify "$vendorBranch" 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "创建新 vendor 分支 $vendorBranch ..." -ForegroundColor Yellow
    git checkout -b $vendorBranch $Version
} else {
    git checkout $vendorBranch
    Write-Host "合并 $Version 到 $vendorBranch ..." -ForegroundColor Yellow
    git merge --no-edit $Version
}

if ($Push) {
    git push origin $vendorBranch
    Write-Host "已推送到 origin/$vendorBranch" -ForegroundColor Green
}

git checkout $currentBranch
Write-Host "`n完成。Vendor 分支 $vendorBranch 已同步到 $Version" -ForegroundColor Green
