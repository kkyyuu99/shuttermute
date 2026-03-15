[CmdletBinding()]
param(
    [ValidateSet('InstallMute', 'Unmute', 'OpenApp')]
    [string]$Action = 'InstallMute',
    [switch]$NoGui,
    [switch]$TrySetVibrateMode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

$script:PackageName = 'android.com.ericswpark.camsung'
$script:MainActivity = 'android.com.ericswpark.camsung/.MainActivity'
$script:CameraSettingKey = 'csc_pref_camera_forced_shuttersound_key'
$script:RepoRoot = Split-Path -Path $PSScriptRoot -Parent
$script:DefaultApkPath = Join-Path $script:RepoRoot 'app\build\outputs\apk\release\app-release.apk'
$script:LogTextBox = $null
$script:TrySetVibrateModeEnabled = $TrySetVibrateMode.IsPresent
$script:IsNoGuiMode = $NoGui.IsPresent

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

function Get-ConnectionGuidanceText {
    param(
        [Parameter(Mandatory = $false)]
        [object[]]$Devices = @()
    )

    $header = @(
        'ADB ?곌껐 以鍮꾧? ?꾩슂?⑸땲??',
        '',
        '?쇱꽦?곗뿉??USB ?붾쾭源?耳쒕뒗 諛⑸쾿:',
        '1. ???좉툑???댁젣?⑸땲??',
        '2. ?ㅼ젙 > ?대??꾪솕 ?뺣낫 > ?뚰봽?몄썾???뺣낫濡??대룞?⑸땲??',
        '3. "鍮뚮뱶踰덊샇"瑜?7踰??곗냽?쇰줈 ?뚮윭 媛쒕컻???듭뀡???쒖꽦?뷀빀?덈떎.',
        '4. ?ㅼ젙 硫붿씤?쇰줈 ?뚯븘媛??媛쒕컻???듭뀡 硫붾돱瑜??쎈땲??',
        '5. "USB ?붾쾭源???耳?땲??',
        '6. USB 耳?대툝???ㅼ떆 ?곌껐?섍퀬, 媛?ν븯硫?USB ?ъ슜 紐⑤뱶瑜?"?뚯씪 ?꾩넚"?쇰줈 諛붽퓠?덈떎.',
        '7. ???붾㈃??"USB ?붾쾭源낆쓣 ?덉슜?섏떆寃좎뒿?덇퉴?" ?앹뾽?먯꽌 "??긽 ??而댄벂?곗뿉???덉슜" 泥댄겕 ???덉슜???꾨쫭?덈떎.',
        '',
        '?앹뾽?????⑤㈃:',
        '- 耳?대툝??類먮떎媛 ?ㅼ떆 ?곌껐?⑸땲??',
        '- 媛쒕컻???듭뀡?먯꽌 USB ?붾쾭源낆쓣 猿먮떎媛 ?ㅼ떆 耳?땲??',
        '- PC 紐낅졊李쎌뿉??adb kill-server ???ㅼ떆 ?쒕룄?⑸땲??',
        '- ???붾㈃??爰쇱졇 ?덉? ?딆?吏 ?뺤씤?⑸땲??'
    )

    if ($Devices.Count -gt 0) {
        $states = $Devices | ForEach-Object { "$($_.Serial) ($($_.State))" }
        $header += ''
        $header += '?꾩옱 媛먯????곹깭:'
        $header += $states

        if (($Devices | Where-Object { $_.State -eq 'unauthorized' }).Count -gt 0) {
            $header += ''
            $header += '吏湲덉? ?곗씠 ?곌껐?섏뿀吏留?RSA ?뱀씤 ???곹깭?낅땲??'
            $header += '???붾㈃?먯꽌 USB ?붾쾭源??덉슜 ?앹뾽???뱀씤?섎㈃ 諛붾줈 ?ㅼ쓬 ?④퀎濡?吏꾪뻾?⑸땲??'
        }
    }

    ($header -join [Environment]::NewLine)
}

function Wait-ForUserToFixConnection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GuidanceText
    )

    Write-Log ''
    foreach ($line in ($GuidanceText -split "`r?`n")) {
        Write-Log $line
    }
    Write-Log ''

    if ($script:IsNoGuiMode) {
        Write-Host ''
        [void](Read-Host 'Press Enter after you finish the USB debugging steps')
        return $true
    }

    $result = [System.Windows.Forms.MessageBox]::Show(
        $GuidanceText + [Environment]::NewLine + [Environment]::NewLine + '以鍮꾧? ?앸궗?쇰㈃ ?뺤씤???뚮윭 ?ㅼ떆 ?쒕룄?⑸땲??',
        'USB ?붾쾭源??ㅼ젙 ?꾩슂',
        [System.Windows.Forms.MessageBoxButtons]::OKCancel,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    return ($result -eq [System.Windows.Forms.DialogResult]::OK)
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

function Get-DeviceEntries {
    param([string]$AdbPath)

    Invoke-ExternalCommand -FilePath $AdbPath -Arguments @('start-server') -AllowFailure | Out-Null
    $result = Invoke-ExternalCommand -FilePath $AdbPath -Arguments @('devices', '-l')
    $lines = $result.StdOut -split "`r?`n" | Where-Object { $_.Trim() }
    $deviceLines = $lines | Where-Object { $_ -notmatch '^List of devices attached' }

    $devices = @(
        foreach ($line in $deviceLines) {
            $parts = $line -split '\s+'
            if ($parts.Count -ge 2) {
                [PSCustomObject]@{
                    Serial = $parts[0]
                    State = $parts[1]
                    Raw = $line
                }
            }
        }
    )

    return $devices
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

    for ($attempt = 1; $attempt -le 4; $attempt++) {
        $devices = @(Get-DeviceEntries -AdbPath $AdbPath)
        $readyDevices = @($devices | Where-Object { $_.State -eq 'device' })

        if ($readyDevices.Count -gt 1) {
            $serials = ($readyDevices | ForEach-Object { $_.Serial }) -join ', '
            throw ("More than one device is connected: {0}. Leave only one phone connected." -f $serials)
        }

        if ($readyDevices.Count -eq 1) {
            return $readyDevices[0].Serial
        }

        $guidanceText = Get-ConnectionGuidanceText -Devices $devices
        $shouldRetry = Wait-ForUserToFixConnection -GuidanceText $guidanceText
        if (-not $shouldRetry) {
            throw 'USB ?붾쾭源?以鍮꾧? 痍⑥냼?섏뿀?듬땲??'
        }
    }

    throw '湲곌린瑜?以鍮꾪뻽吏留?ADB ?곌껐???꾩쭅 ?꾨즺?섏? ?딆븯?듬땲?? USB 耳?대툝, USB ?붾쾭源? RSA ?뱀씤 ?앹뾽???ㅼ떆 ?뺤씤??二쇱꽭??'
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
