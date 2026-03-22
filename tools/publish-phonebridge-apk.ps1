[CmdletBinding()]
param(
    [string]$Configuration = 'Release'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$outputPath = Join-Path $repoRoot 'build\phonebridge-apk'
$apkSourcePath = Join-Path $repoRoot "phonebridge\build\outputs\apk\release\phonebridge-release.apk"
$apkTargetPath = Join-Path $outputPath 'ShutterMute-PhoneBridge.apk'

if (-not $env:JAVA_HOME) {
    $studioJbr = 'C:\Program Files\Android\Android Studio\jbr'
    if (Test-Path $studioJbr) {
        $env:JAVA_HOME = $studioJbr
        $env:PATH = "$($env:JAVA_HOME)\bin;$($env:PATH)"
    }
}

if (-not $env:ANDROID_HOME) {
    $defaultSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
    if (Test-Path $defaultSdk) {
        $env:ANDROID_HOME = $defaultSdk
    }
}

if (-not $env:ANDROID_HOME) {
    throw 'ANDROID_HOME 또는 local.properties 없이 Android SDK를 찾을 수 없습니다.'
}

Push-Location $repoRoot
try {
    ./gradlew ":phonebridge:assemble$Configuration"

    if (-not (Test-Path $apkSourcePath)) {
        throw "빌드된 APK를 찾지 못했습니다: $apkSourcePath"
    }

    New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
    Copy-Item -Path $apkSourcePath -Destination $apkTargetPath -Force

    Write-Host ''
    Write-Host 'Published phone-to-phone APK:'
    Get-ChildItem -Path $apkTargetPath | Select-Object Name, Length, LastWriteTime
}
finally {
    Pop-Location
}
