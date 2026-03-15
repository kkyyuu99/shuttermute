[CmdletBinding()]
param(
    [string]$Configuration = 'Release',
    [string]$Runtime = 'win-x64'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$projectPath = Join-Path $PSScriptRoot 'CamsungOneClickExe\CamsungOneClickExe.csproj'
$outputPath = Join-Path $repoRoot 'build\oneclick-exe'

dotnet publish $projectPath `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:EnableCompressionInSingleFile=true `
    -p:DebugType=None `
    -p:DebugSymbols=false `
    -o $outputPath

Write-Host ''
Write-Host "Published EXE:"
Get-ChildItem -Path $outputPath | Select-Object Name, Length, LastWriteTime
