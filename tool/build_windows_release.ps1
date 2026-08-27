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
} finally {
  if (Test-Path $stagingDir) {
    Remove-Item $stagingDir -Recurse -Force
  }
}
