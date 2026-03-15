[CmdletBinding()]
param(
    [string]$Configuration = 'Release',
    [string]$Runtime = 'win-x64'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$projectPath = Join-Path $PSScriptRoot 'ShutterMuteExe\ShutterMuteExe.csproj'
$outputPath = Join-Path $repoRoot 'build\shuttermute-exe'

function Resolve-AdbBundleDir {
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($command) {
        return Split-Path -Path $command.Source -Parent
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools'),
        'C:\Users\kkyyu\AppData\Local\Android\Sdk\platform-tools'
    )

    foreach ($candidate in $candidates) {
        if (Test-Path (Join-Path $candidate 'adb.exe')) {
            return $candidate
        }
    }

    throw 'adb.exe를 포함한 Android platform-tools 폴더를 찾지 못했습니다.'
}

$adbBundleDir = Resolve-AdbBundleDir
Write-Host "Bundling ADB from: $adbBundleDir"

dotnet publish $projectPath `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:EnableCompressionInSingleFile=true `
    -p:AdbBundleDir="$adbBundleDir" `
    -p:DebugType=None `
    -p:DebugSymbols=false `
    -o $outputPath

Write-Host ''
Write-Host "Published EXE:"
Get-ChildItem -Path $outputPath | Select-Object Name, Length, LastWriteTime
