# Install meta_ota from the latest GitHub Release (Windows x64).
# Usage (PowerShell):
#   irm https://raw.githubusercontent.com/josercc/meta_ota_cli/main/install.ps1 | iex
#   $env:META_OTA_VERSION='v0.1.0'; irm ... | iex
#   $env:META_OTA_PREFIX="$env:LOCALAPPDATA\meta_ota"; irm ... | iex
$ErrorActionPreference = 'Stop'

$Repo = 'josercc/meta_ota_cli'
$Asset = 'meta_ota-windows-x64.exe'
$Version = if ($env:META_OTA_VERSION) { $env:META_OTA_VERSION } else { 'latest' }
$Prefix = if ($env:META_OTA_PREFIX) { $env:META_OTA_PREFIX } else { Join-Path $env:LOCALAPPDATA 'meta_ota' }
$Dest = Join-Path $Prefix 'meta_ota.exe'

if ($Version -eq 'latest') {
  $ApiUrl = "https://api.github.com/repos/$Repo/releases/latest"
} else {
  $ApiUrl = "https://api.github.com/repos/$Repo/releases/tags/$Version"
}

Write-Host "==> Resolving release ($Version)..."
$release = Invoke-RestMethod -Uri $ApiUrl -Headers @{ 'User-Agent' = 'meta_ota-install' }
$assetInfo = $release.assets | Where-Object { $_.name -eq $Asset } | Select-Object -First 1
if (-not $assetInfo) {
  throw "Could not find asset '$Asset' in $($release.tag_name). See https://github.com/$Repo/releases"
}

New-Item -ItemType Directory -Force -Path $Prefix | Out-Null
$tmp = Join-Path $env:TEMP ("meta_ota-" + [guid]::NewGuid().ToString() + '.exe')

Write-Host "==> Downloading $Asset ($($release.tag_name))..."
Invoke-WebRequest -Uri $assetInfo.browser_download_url -OutFile $tmp -UseBasicParsing
Move-Item -Force $tmp $Dest

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$Prefix*") {
  Write-Host "==> Adding $Prefix to user PATH..."
  [Environment]::SetEnvironmentVariable('Path', "$userPath;$Prefix", 'User')
  $env:Path = "$env:Path;$Prefix"
}

Write-Host "==> Installed: $Dest"
Write-Host "Done. Open a new terminal and run: meta_ota --help"
