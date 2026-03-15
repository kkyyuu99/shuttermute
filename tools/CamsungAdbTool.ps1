[CmdletBinding()]
param(
    [ValidateSet('InstallMute', 'Unmute', 'OpenApp')]
    [string]$Action = 'InstallMute',
    [switch]$NoGui,
    [switch]$TrySetVibrateMode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:PackageName = 'android.com.ericswpark.camsung'
$script:MainActivity = 'android.com.ericswpark.camsung/.MainActivity'
$script:CameraSettingKey = 'csc_pref_camera_forced_shuttersound_key'
$script:RepoRoot = Split-Path -Path $PSScriptRoot -Parent
$script:DefaultApkPath = Join-Path $script:RepoRoot 'app\build\outputs\apk\release\app-release.apk'
$script:LogTextBox = $null
$script:TrySetVibrateModeEnabled = $TrySetVibrateMode.IsPresent

function Write-Log {
    param([string]$Message)

    $timestamp = Get-Date -Format 'HH:mm:ss'
    $line = "[$timestamp] $Message"
    Write-Host $line

    if ($script:LogTextBox) {
        $script:LogTextBox.AppendText($line + [Environment]::NewLine)
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Find-AdbPath {
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = @('C:\Users\kkyyu\AppData\Local\Android\Sdk\platform-tools\adb.exe')

    if ($env:LOCALAPPDATA) {
        $candidates += Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    }
    if ($env:ANDROID_HOME) {
        $candidates += Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
    }
    if ($env:ANDROID_SDK_ROOT) {
        $candidates += Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe'
    }

    $candidates = @($candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique)

    if ($candidates.Count -gt 0) {
        return $candidates[0]
    }

    throw 'adb.exe was not found. Install Android platform-tools or Android Studio first.'
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $renderedArgs = $Arguments | ForEach-Object {
        if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
    }
    Write-Log ("Running: {0} {1}" -f $FilePath, ($renderedArgs -join ' '))

    $quotedArgs = $Arguments | ForEach-Object {
        $value = $_ -replace '"', '\"'
        if ($value -match '\s') {
            '"' + $value + '"'
        } else {
            $value
        }
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $quotedArgs -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($stdout.Trim()) {
        Write-Log $stdout.Trim()
    }
    if ($stderr.Trim()) {
        Write-Log $stderr.Trim()
    }

    if (-not $AllowFailure -and $process.ExitCode -ne 0) {
        throw ("Command failed with exit code {0}." -f $process.ExitCode)
    }

    [PSCustomObject]@{
        ExitCode = $process.ExitCode
        StdOut = $stdout
        StdErr = $stderr
    }
}

function Get-ReadyDeviceSerial {
    param([string]$AdbPath)

    $result = Invoke-ExternalCommand -FilePath $AdbPath -Arguments @('devices')
    $lines = $result.StdOut -split "`r?`n" | Where-Object { $_.Trim() }
    $deviceLines = $lines | Where-Object { $_ -notmatch '^List of devices attached' }

    if (-not $deviceLines) {
        throw 'No Android device is connected. Connect the phone with USB, enable USB debugging, and accept the RSA prompt.'
    }

    $devices = foreach ($line in $deviceLines) {
        $parts = $line -split '\s+'
        if ($parts.Count -ge 2) {
            [PSCustomObject]@{
                Serial = $parts[0]
                State = $parts[1]
            }
        }
    }

    $readyDevices = $devices | Where-Object { $_.State -eq 'device' }
    if ($readyDevices.Count -eq 0) {
        $states = ($devices | ForEach-Object { "$($_.Serial) ($($_.State))" }) -join ', '
        throw ("Connected device is not ready yet: {0}" -f $states)
    }

    if ($readyDevices.Count -gt 1) {
        $serials = ($readyDevices | ForEach-Object { $_.Serial }) -join ', '
        throw ("More than one device is connected: {0}. Leave only one phone connected." -f $serials)
    }

    return $readyDevices[0].Serial
}

function Invoke-Adb {
    param(
        [string]$AdbPath,
        [string]$Serial,
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $fullArgs = @()
    if ($Serial) {
        $fullArgs += @('-s', $Serial)
    }
    $fullArgs += $Arguments

    Invoke-ExternalCommand -FilePath $AdbPath -Arguments $fullArgs -AllowFailure:$AllowFailure
}

function Install-CamsungApk {
    param(
        [string]$AdbPath,
        [string]$Serial,
        [string]$ApkPath
    )

    if (-not (Test-Path $ApkPath)) {
        throw ("APK not found: {0}" -f $ApkPath)
    }

    $installResult = Invoke-Adb -AdbPath $AdbPath -Serial $Serial -Arguments @('install', '-r', '--bypass-low-target-sdk-block', $ApkPath) -AllowFailure
    $combinedOutput = ($installResult.StdOut + "`n" + $installResult.StdErr)

    if ($installResult.ExitCode -eq 0) {
        return
    }

    if ($combinedOutput -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|INSTALL_PARSE_FAILED_INCONSISTENT_CERTIFICATES|INSTALL_FAILED_VERSION_DOWNGRADE') {
        Write-Log 'Existing app install is incompatible with this APK. Removing the old app and retrying.'
        Invoke-Adb -AdbPath $AdbPath -Serial $Serial -Arguments @('uninstall', $script:PackageName) -AllowFailure
        Invoke-Adb -AdbPath $AdbPath -Serial $Serial -Arguments @('install', '-r', '--bypass-low-target-sdk-block', $ApkPath)
        return
    }

    throw 'APK installation failed.'
}

function Enable-CamsungWriteSettings {
    param(
        [string]$AdbPath,
        [string]$Serial
    )

    Invoke-Adb -AdbPath $AdbPath -Serial $Serial -Arguments @('shell', 'appops', 'set', $script:PackageName, 'WRITE_SETTINGS', 'allow')
}

function Set-CamsungMuteValue {
    param(
        [string]$AdbPath,
        [string]$Serial,
        [ValidateSet('0', '1')]
        [string]$Value
    )

    Invoke-Adb -AdbPath $AdbPath -Serial $Serial -Arguments @('shell', 'settings', 'put', 'system', $script:CameraSettingKey, $Value)
}

function Open-CamsungApp {
    param(
        [string]$AdbPath,
        [string]$Serial
    )

    Invoke-Adb -AdbPath $AdbPath -Serial $Serial -Arguments @('shell', 'am', 'start', '-n', $script:MainActivity)
}

function Try-EnableVibrateMode {
    param(
        [string]$AdbPath,
        [string]$Serial
    )

    $attempts = @(
        @('shell', 'cmd', 'audio', 'set-ringer-mode', 'vibrate'),
        @('shell', 'cmd', 'audio', 'set-ringer-mode', '1')
    )

    foreach ($attempt in $attempts) {
        $result = Invoke-Adb -AdbPath $AdbPath -Serial $Serial -Arguments $attempt -AllowFailure
        if ($result.ExitCode -eq 0) {
            Write-Log 'Best-effort vibrate mode command succeeded.'
            return
        }
    }

    Write-Log 'Best-effort vibrate mode command was not supported on this device. If shutter sound remains, set the phone to Vibrate or Silent manually.'
}

function Run-InstallMuteWorkflow {
    $adbPath = Find-AdbPath
    $serial = Get-ReadyDeviceSerial -AdbPath $adbPath

    Write-Log ("Using device: {0}" -f $serial)
    Install-CamsungApk -AdbPath $adbPath -Serial $serial -ApkPath $script:DefaultApkPath
    Enable-CamsungWriteSettings -AdbPath $adbPath -Serial $serial
    Set-CamsungMuteValue -AdbPath $adbPath -Serial $serial -Value '0'

    if ($script:TrySetVibrateModeEnabled) {
        Try-EnableVibrateMode -AdbPath $adbPath -Serial $serial
    } else {
        Write-Log 'Phone ringer mode was left unchanged. For some Samsung builds, Vibrate or Silent mode is still required.'
    }

    Write-Log 'Install + mute workflow completed.'
}

function Run-UnmuteWorkflow {
    $adbPath = Find-AdbPath
    $serial = Get-ReadyDeviceSerial -AdbPath $adbPath

    Write-Log ("Using device: {0}" -f $serial)
    Set-CamsungMuteValue -AdbPath $adbPath -Serial $serial -Value '1'
    Write-Log 'Camera shutter sound was set back to normal.'
}

function Run-OpenAppWorkflow {
    $adbPath = Find-AdbPath
    $serial = Get-ReadyDeviceSerial -AdbPath $adbPath

    Write-Log ("Using device: {0}" -f $serial)
    Open-CamsungApp -AdbPath $adbPath -Serial $serial
    Write-Log 'camsung app launch command sent.'
}

function Invoke-Action {
    param([string]$RequestedAction)

    switch ($RequestedAction) {
        'InstallMute' { Run-InstallMuteWorkflow }
        'Unmute' { Run-UnmuteWorkflow }
        'OpenApp' { Run-OpenAppWorkflow }
        default { throw ("Unsupported action: {0}" -f $RequestedAction) }
    }
}

if ($NoGui) {
    try {
        Invoke-Action -RequestedAction $Action
        exit 0
    } catch {
        Write-Host ("ERROR: {0}" -f $_.Exception.Message)
        exit 1
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'camsung ADB One-Click Tool'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(760, 520)
$form.MinimumSize = New-Object System.Drawing.Size(760, 520)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Install and control camsung from Windows with one click'
$title.Location = New-Object System.Drawing.Point(16, 16)
$title.Size = New-Object System.Drawing.Size(700, 24)
$title.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "APK: $script:DefaultApkPath"
$subtitle.Location = New-Object System.Drawing.Point(16, 48)
$subtitle.Size = New-Object System.Drawing.Size(710, 36)
$form.Controls.Add($subtitle)

$vibrateCheck = New-Object System.Windows.Forms.CheckBox
$vibrateCheck.Text = 'Try to switch the phone to Vibrate mode too (best effort)'
$vibrateCheck.Location = New-Object System.Drawing.Point(16, 86)
$vibrateCheck.Size = New-Object System.Drawing.Size(420, 24)
$vibrateCheck.Checked = $true
$form.Controls.Add($vibrateCheck)

$installMuteButton = New-Object System.Windows.Forms.Button
$installMuteButton.Text = 'Install + Mute'
$installMuteButton.Location = New-Object System.Drawing.Point(16, 120)
$installMuteButton.Size = New-Object System.Drawing.Size(150, 36)
$form.Controls.Add($installMuteButton)

$unmuteButton = New-Object System.Windows.Forms.Button
$unmuteButton.Text = 'Unmute'
$unmuteButton.Location = New-Object System.Drawing.Point(176, 120)
$unmuteButton.Size = New-Object System.Drawing.Size(120, 36)
$form.Controls.Add($unmuteButton)

$openAppButton = New-Object System.Windows.Forms.Button
$openAppButton.Text = 'Open App'
$openAppButton.Location = New-Object System.Drawing.Point(306, 120)
$openAppButton.Size = New-Object System.Drawing.Size(120, 36)
$form.Controls.Add($openAppButton)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(16, 172)
$logBox.Size = New-Object System.Drawing.Size(712, 292)
$logBox.Multiline = $true
$logBox.ScrollBars = 'Vertical'
$logBox.ReadOnly = $true
$logBox.Font = New-Object System.Drawing.Font('Consolas', 10)
$form.Controls.Add($logBox)
$script:LogTextBox = $logBox

function Invoke-UiAction {
    param([string]$RequestedAction)

    $form.UseWaitCursor = $true
    $installMuteButton.Enabled = $false
    $unmuteButton.Enabled = $false
    $openAppButton.Enabled = $false
    $script:TrySetVibrateModeEnabled = $vibrateCheck.Checked

    try {
        Invoke-Action -RequestedAction $RequestedAction
        [System.Windows.Forms.MessageBox]::Show('Completed successfully.', 'camsung ADB Tool')
    } catch {
        Write-Log ("ERROR: {0}" -f $_.Exception.Message)
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'camsung ADB Tool')
    } finally {
        $form.UseWaitCursor = $false
        $installMuteButton.Enabled = $true
        $unmuteButton.Enabled = $true
        $openAppButton.Enabled = $true
    }
}

$installMuteButton.Add_Click({ Invoke-UiAction -RequestedAction 'InstallMute' })
$unmuteButton.Add_Click({ Invoke-UiAction -RequestedAction 'Unmute' })
$openAppButton.Add_Click({ Invoke-UiAction -RequestedAction 'OpenApp' })

Write-Log 'Ready. Connect one Android device with USB debugging enabled, then click Install + Mute.'
[void]$form.ShowDialog()
