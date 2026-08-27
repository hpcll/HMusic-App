param()

$ErrorActionPreference = "Stop"
$rootDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $rootDir

$versionLine = Select-String -Path "pubspec.yaml" -Pattern '^version:\s*([^+\s]+)' | Select-Object -First 1
if (-not $versionLine) {
  throw "无法从 pubspec.yaml 读取版本号"
}
$version = $versionLine.Matches[0].Groups[1].Value

flutter clean
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get 失败" }

$generatedRegistrant = "android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java"
if (Test-Path $generatedRegistrant) {
  Remove-Item $generatedRegistrant -Force
}

flutter build windows --release --no-pub
if ($LASTEXITCODE -ne 0) { throw "Windows Release 构建失败" }

$bundlePath = Join-Path $rootDir "build/windows/x64/runner/Release"
$executable = Join-Path $bundlePath "hmusic.exe"
if (-not (Test-Path $executable)) {
  throw "Windows 构建未生成 hmusic.exe"
}

$distDir = Join-Path $rootDir "dist"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) ("hmusic-windows-" + [Guid]::NewGuid().ToString("N"))
$appDir = Join-Path $stagingDir "HMusic"
New-Item -ItemType Directory -Force -Path $appDir | Out-Null

try {
  Copy-Item (Join-Path $bundlePath "*") $appDir -Recurse -Force
  $archive = Join-Path $distDir "hmusic-$version-windows-x64.zip"
  if (Test-Path $archive) { Remove-Item $archive -Force }
  Compress-Archive -Path $appDir -DestinationPath $archive -CompressionLevel Optimal

  $archiveName = Split-Path $archive -Leaf
  $digest = (Get-FileHash -Algorithm SHA256 $archive).Hash.ToLowerInvariant()
  Set-Content -Path "$archive.sha256" -Value "$digest  $archiveName" -Encoding ascii
  Write-Host "Windows x64 便携包已写入 $archive"

  $installerScript = Join-Path $rootDir "tool/windows-installer.iss"
  $iconFile = Join-Path $rootDir "windows/runner/resources/app_icon.ico"
  if (-not (Test-Path $installerScript)) {
    throw "Windows 安装向导脚本不存在: $installerScript"
  }
  if (-not (Test-Path $iconFile)) {
    throw "Windows 安装包图标不存在: $iconFile"
  }

  $iscc = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
  if (-not $iscc) {
    throw "未找到 Inno Setup 编译器 ISCC.exe。请先安装 Inno Setup 6，或在 GitHub Actions 中使用已配置的安装步骤。"
  }

  $languageFile = Join-Path $stagingDir "ChineseSimplified.isl"
  $languageUrl = "https://raw.githubusercontent.com/jrsoftware/issrc/1ae7bf81dc0d2013235dfe4bb0b6f4e4a0b6b25c/Files/Languages/ChineseSimplified.isl"
  $expectedLanguageDigest = "e0b0b350e2245f3c5e65586dfe43d574f6e7f06f2261149aba284954b3fc9a8d"
  $previousProgressPreference = $ProgressPreference
  try {
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $languageUrl -OutFile $languageFile
  } finally {
    $ProgressPreference = $previousProgressPreference
  }
  $languageDigest = (Get-FileHash -Algorithm SHA256 $languageFile).Hash.ToLowerInvariant()
  if ($languageDigest -ne $expectedLanguageDigest) {
    throw "Inno Setup 简体中文语言文件校验失败"
  }

  $installerArgs = @(
    "/DAppVersion=$version",
    "/DSourceDir=$bundlePath",
    "/DOutputDir=$distDir",
    "/DIconFile=$iconFile",
    "/DLanguageFile=$languageFile",
    $installerScript
  )
  & $iscc.Source @installerArgs
  if ($LASTEXITCODE -ne 0) { throw "Windows 安装包编译失败" }

  $installer = Join-Path $distDir "hmusic-$version-windows-x64-setup.exe"
  if (-not (Test-Path $installer)) {
    throw "Inno Setup 未生成安装包: $installer"
  }
  $installerName = Split-Path $installer -Leaf
  $installerDigest = (Get-FileHash -Algorithm SHA256 $installer).Hash.ToLowerInvariant()
  Set-Content -Path "$installer.sha256" -Value "$installerDigest  $installerName" -Encoding ascii
  Write-Host "Windows x64 安装包已写入 $installer"
} finally {
  if (Test-Path $stagingDir) {
    Remove-Item $stagingDir -Recurse -Force
  }
}
