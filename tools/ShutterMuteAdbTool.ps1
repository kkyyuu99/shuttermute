[CmdletBinding()]
param(
    [ValidateSet('InstallMute', 'Unmute', 'OpenApp')]
    [string]$Action = 'InstallMute',
    [switch]$NoGui,
    [switch]$TrySetVibrateMode,
    [switch]$PauseOnExit,
    [ValidateSet('ko', 'ja')]
    [string]$Language
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

$script:PackageName = 'io.github.kkyyuu.shuttermute'
$script:MainActivity = 'io.github.kkyyuu.shuttermute/.MainActivity'
$script:CameraSettingKey = 'csc_pref_camera_forced_shuttersound_key'
$script:RepoRoot = Split-Path -Path $PSScriptRoot -Parent
$script:DefaultApkPath = Join-Path $script:RepoRoot 'app\build\outputs\apk\release\app-release.apk'
$script:IsNoGuiMode = $NoGui.IsPresent
$script:TrySetVibrateModeEnabled = $TrySetVibrateMode.IsPresent
$script:LogTextBox = $null
$script:CurrentLanguage = 'ko'
$script:LanguageOptions = @(
    [PSCustomObject]@{ Code = 'ko'; Label = '한국어 (Korean)' }
    [PSCustomObject]@{ Code = 'ja'; Label = '日本語 (Japanese)' }
)
$script:FallbackStrings = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'lang\ko.psd1')
$script:Strings = $script:FallbackStrings

function Get-Text {
    param([string]$Key)

    if ($script:Strings.ContainsKey($Key)) { return $script:Strings[$Key] }
    if ($script:FallbackStrings.ContainsKey($Key)) { return $script:FallbackStrings[$Key] }
    return $Key
}

function Set-Language {
    param([string]$Code)

    $script:CurrentLanguage = $Code
    $path = Join-Path $PSScriptRoot ("lang\{0}.psd1" -f $Code)
    if (Test-Path $path) {
        $script:Strings = Import-PowerShellDataFile $path
    } else {
        $script:Strings = $script:FallbackStrings
    }
}

function Write-Log {
    param([string]$Message)

    $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message
    Write-Host $line
    if ($script:LogTextBox) {
        $script:LogTextBox.AppendText($line + [Environment]::NewLine)
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Resolve-DefaultLanguageCode {
    $name = [System.Globalization.CultureInfo]::CurrentUICulture.Name
    switch -Regex ($name) {
        '^ja' { return 'ja' }
        default { return 'ko' }
    }
}

function Select-LanguageConsole {
    param([string]$DefaultCode)

    while ($true) {
        Write-Host ''
        Write-Host 'Choose language'
        for ($i = 0; $i -lt $script:LanguageOptions.Count; $i++) {
            $option = $script:LanguageOptions[$i]
            $suffix = if ($option.Code -eq $DefaultCode) { ' (default)' } else { '' }
            Write-Host ("{0}. {1}{2}" -f ($i + 1), $option.Label, $suffix)
        }
        $choice = Read-Host 'Number'
        if ([string]::IsNullOrWhiteSpace($choice)) { return $DefaultCode }
        $number = 0
        if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $script:LanguageOptions.Count) {
            return $script:LanguageOptions[$number - 1].Code
        }
    }
}

function Select-LanguageGui {
    param([string]$DefaultCode)

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Language'
    $form.StartPosition = 'CenterScreen'
    $form.Size = New-Object System.Drawing.Size(420, 180)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = 'Choose your language'
    $label.Location = New-Object System.Drawing.Point(16, 18)
    $label.Size = New-Object System.Drawing.Size(360, 20)
    $form.Controls.Add($label)

    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.DropDownStyle = 'DropDownList'
    $combo.Location = New-Object System.Drawing.Point(16, 52)
    $combo.Size = New-Object System.Drawing.Size(370, 24)
    foreach ($option in $script:LanguageOptions) { [void]$combo.Items.Add($option.Label) }
    $defaultIndex = 0
    for ($i = 0; $i -lt $script:LanguageOptions.Count; $i++) {
        if ($script:LanguageOptions[$i].Code -eq $DefaultCode) { $defaultIndex = $i; break }
    }
    $combo.SelectedIndex = $defaultIndex
    $form.Controls.Add($combo)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'OK'
    $ok.Location = New-Object System.Drawing.Point(220, 94)
    $ok.Size = New-Object System.Drawing.Size(75, 28)
    $ok.Add_Click({
        $form.Tag = $script:LanguageOptions[$combo.SelectedIndex].Code
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $form.Controls.Add($ok)
    $form.AcceptButton = $ok

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Location = New-Object System.Drawing.Point(305, 94)
    $cancel.Size = New-Object System.Drawing.Size(80, 28)
    $cancel.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Close()
    })
    $form.Controls.Add($cancel)
    $form.CancelButton = $cancel

    if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
    return [string]$form.Tag
}

function Initialize-Language {
    if ($Language) { Set-Language $Language; return }
    $defaultCode = Resolve-DefaultLanguageCode
    if ($script:IsNoGuiMode) {
        Set-Language (Select-LanguageConsole -DefaultCode $defaultCode)
    } else {
        $selected = Select-LanguageGui -DefaultCode $defaultCode
        if (-not $selected) { exit 1 }
        Set-Language $selected
    }
}

function Get-ConnectionGuidanceText {
    param([object[]]$Devices = @())

    $lines = @()
    $lines += Get-Text 'NeedUsbDebugBody'
    if ($Devices.Count -gt 0) {
        $lines += ''
        $lines += Get-Text 'DetectedState'
        $lines += ($Devices | ForEach-Object { "$($_.Serial) ($($_.State))" })
        if ((@($Devices | Where-Object { $_.State -eq 'unauthorized' })).Count -gt 0) {
            $lines += ''
            $lines += Get-Text 'Unauthorized1'
            $lines += Get-Text 'Unauthorized2'
        }
    }
    return ($lines -join [Environment]::NewLine)
}

function Wait-ForUserToFixConnection {
    param([string]$GuidanceText)

    Write-Log ''
    foreach ($line in ($GuidanceText -split "`r?`n")) { Write-Log $line }
    Write-Log ''

    if ($script:IsNoGuiMode) {
        [void](Read-Host (Get-Text 'RetryPrompt'))
        return $true
    }

    $result = [System.Windows.Forms.MessageBox]::Show(
        $GuidanceText + [Environment]::NewLine + [Environment]::NewLine + (Get-Text 'RetryDialog'),
        (Get-Text 'NeedUsbDebugTitle'),
        [System.Windows.Forms.MessageBoxButtons]::OKCancel,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
    return ($result -eq [System.Windows.Forms.DialogResult]::OK)
}

function Find-AdbPath {
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $candidates = @(
        'C:\Users\kkyyu\AppData\Local\Android\Sdk\platform-tools\adb.exe',
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe')
    ) | Where-Object { $_ -and (Test-Path $_) }
    if ($candidates.Count -gt 0) { return $candidates[0] }
    throw (Get-Text 'AdbNotFound')
}

function Invoke-ExternalCommand {
    param([string]$FilePath, [string[]]$Arguments, [switch]$AllowFailure)

    $shownArgs = $Arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
    Write-Log ("Running: {0} {1}" -f $FilePath, ($shownArgs -join ' '))

    $quotedArgs = $Arguments | ForEach-Object {
        $value = $_ -replace '"', '\"'
        if ($value -match '\s') { '"' + $value + '"' } else { $value }
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

    if ($stdout.Trim()) { Write-Log $stdout.Trim() }
    if ($stderr.Trim()) { Write-Log $stderr.Trim() }
    if (-not $AllowFailure -and $process.ExitCode -ne 0) {
        throw ("Command failed with exit code {0}." -f $process.ExitCode)
    }

    [PSCustomObject]@{ ExitCode = $process.ExitCode; StdOut = $stdout; StdErr = $stderr }
}

function Get-DeviceEntries {
    param([string]$AdbPath)

    Invoke-ExternalCommand -FilePath $AdbPath -Arguments @('start-server') -AllowFailure | Out-Null
    $result = Invoke-ExternalCommand -FilePath $AdbPath -Arguments @('devices', '-l')
    $lines = $result.StdOut -split "`r?`n" | Where-Object { $_.Trim() }
    $deviceLines = $lines | Where-Object { $_ -notmatch '^List of devices attached' }
    return @(
        foreach ($line in $deviceLines) {
            $parts = $line -split '\s+'
            if ($parts.Count -ge 2) {
                [PSCustomObject]@{ Serial = $parts[0]; State = $parts[1] }
            }
        }
    )
}

function Get-ReadyDeviceSerial {
    param([string]$AdbPath)

    for ($attempt = 1; $attempt -le 4; $attempt++) {
        $devices = @(Get-DeviceEntries -AdbPath $AdbPath)
        $readyDevices = @($devices | Where-Object { $_.State -eq 'device' })
        if ($readyDevices.Count -gt 1) {
            $serials = ($readyDevices | ForEach-Object { $_.Serial }) -join ', '
            throw ((Get-Text 'MoreThanOneDevice') -f $serials)
        }
        if ($readyDevices.Count -eq 1) { return $readyDevices[0].Serial }
        $guidanceText = Get-ConnectionGuidanceText -Devices $devices
        if (-not (Wait-ForUserToFixConnection -GuidanceText $guidanceText)) {
            throw (Get-Text 'ConnectionCancelled')
        }
    }
    throw (Get-Text 'ConnectionStillNotReady')
}

function Invoke-Adb {
    param([string]$AdbPath, [string]$Serial, [string[]]$Arguments, [switch]$AllowFailure)

    $fullArgs = @()
    if ($Serial) { $fullArgs += @('-s', $Serial) }
    $fullArgs += $Arguments
    Invoke-ExternalCommand -FilePath $AdbPath -Arguments $fullArgs -AllowFailure:$AllowFailure
}

function Install-ShutterMuteApk {
    param([string]$AdbPath, [string]$Serial, [string]$ApkPath)

    if (-not (Test-Path $ApkPath)) { throw ((Get-Text 'ApkNotFound') -f $ApkPath) }
    $install = Invoke-Adb -AdbPath $AdbPath -Serial $Serial -Arguments @('install', '-r', '--bypass-low-target-sdk-block', $ApkPath) -AllowFailure
    $combined = $install.StdOut + "`n" + $install.StdErr
    if ($install.ExitCode -eq 0) { return }
    if ($combined -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|INSTALL_PARSE_FAILED_INCONSISTENT_CERTIFICATES|INSTALL_FAILED_VERSION_DOWNGRADE') {
        Write-Log (Get-Text 'ExistingInstallIncompatible')
        Invoke-Adb -AdbPath $AdbPath -Serial $Serial -Arguments @('uninstall', $script:PackageName) -AllowFailure | Out-Null
        Invoke-Adb -AdbPath $AdbPath -Serial $Serial -Arguments @('install', '-r', '--bypass-low-target-sdk-block', $ApkPath) | Out-Null
        return
    }
    throw (Get-Text 'ApkInstallFailed')
}

function Enable-ShutterMuteWriteSettings {
    param([string]$AdbPath, [string]$Serial)
    Invoke-Adb -AdbPath $AdbPath -Serial $Serial -Arguments @('shell', 'appops', 'set', $script:PackageName, 'WRITE_SETTINGS', 'allow') | Out-Null
}

function Set-ShutterMuteValue {
    param([string]$AdbPath, [string]$Serial, [ValidateSet('0', '1')] [string]$Value)
    Invoke-Adb -AdbPath $AdbPath -Serial $Serial -Arguments @('shell', 'settings', 'put', 'system', $script:CameraSettingKey, $Value) | Out-Null
}

function Open-ShutterMuteApp {
    param([string]$AdbPath, [string]$Serial)
    Invoke-Adb -AdbPath $AdbPath -Serial $Serial -Arguments @('shell', 'am', 'start', '-n', $script:MainActivity) | Out-Null
}

function Try-EnableVibrateMode {
    param([string]$AdbPath, [string]$Serial)
    $attempts = @(
        @('shell', 'cmd', 'audio', 'set-ringer-mode', 'VIBRATE'),
        @('shell', 'cmd', 'audio', 'set-ringer-mode', 'SILENT')
    )
    foreach ($attempt in $attempts) {
        $result = Invoke-Adb -AdbPath $AdbPath -Serial $Serial -Arguments $attempt -AllowFailure
        if ($result.ExitCode -eq 0) {
            Write-Log (Get-Text 'VibrateSuccess')
            return
        }
    }
    Write-Log (Get-Text 'VibrateUnsupported')
}

function Run-InstallMuteWorkflow {
    $adbPath = Find-AdbPath
    $serial = Get-ReadyDeviceSerial -AdbPath $adbPath
    Write-Log ((Get-Text 'UsingDevice') -f $serial)
        Install-ShutterMuteApk -AdbPath $adbPath -Serial $serial -ApkPath $script:DefaultApkPath
        Enable-ShutterMuteWriteSettings -AdbPath $adbPath -Serial $serial
        Set-ShutterMuteValue -AdbPath $adbPath -Serial $serial -Value '0'
    if ($script:TrySetVibrateModeEnabled) { Try-EnableVibrateMode -AdbPath $adbPath -Serial $serial } else { Write-Log (Get-Text 'RingerUnchanged') }
    Write-Log (Get-Text 'InstallMuteDone')
}

function Run-UnmuteWorkflow {
    $adbPath = Find-AdbPath
    $serial = Get-ReadyDeviceSerial -AdbPath $adbPath
    Write-Log ((Get-Text 'UsingDevice') -f $serial)
        Set-ShutterMuteValue -AdbPath $adbPath -Serial $serial -Value '1'
    Write-Log (Get-Text 'UnmuteDone')
}

function Run-OpenAppWorkflow {
    $adbPath = Find-AdbPath
    $serial = Get-ReadyDeviceSerial -AdbPath $adbPath
    Write-Log ((Get-Text 'UsingDevice') -f $serial)
        Open-ShutterMuteApp -AdbPath $adbPath -Serial $serial
    Write-Log (Get-Text 'OpenAppDone')
}

if ($NoGui) {
    Initialize-Language
    try {
        switch ($Action) {
            'InstallMute' { Run-InstallMuteWorkflow }
            'Unmute' { Run-UnmuteWorkflow }
            'OpenApp' { Run-OpenAppWorkflow }
        }
        Write-Host (Get-Text 'Finished')
        if ($PauseOnExit) { [void](Read-Host (Get-Text 'ClosePrompt')) }
        exit 0
    } catch {
        Write-Host ("{0}: {1}" -f (Get-Text 'Error'), $_.Exception.Message)
        if ($PauseOnExit) { [void](Read-Host (Get-Text 'ClosePrompt')) }
        exit 1
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Initialize-Language

$form = New-Object System.Windows.Forms.Form
$form.Text = Get-Text 'Title'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(760, 520)
$form.MinimumSize = New-Object System.Drawing.Size(760, 520)

$title = New-Object System.Windows.Forms.Label
$title.Text = Get-Text 'Subtitle'
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
$vibrateCheck.Text = Get-Text 'VibrateCheckbox'
$vibrateCheck.Location = New-Object System.Drawing.Point(16, 86)
$vibrateCheck.Size = New-Object System.Drawing.Size(520, 24)
$vibrateCheck.Checked = $true
$form.Controls.Add($vibrateCheck)

$installMuteButton = New-Object System.Windows.Forms.Button
$installMuteButton.Text = Get-Text 'InstallMuteButton'
$installMuteButton.Location = New-Object System.Drawing.Point(16, 120)
$installMuteButton.Size = New-Object System.Drawing.Size(170, 36)
$form.Controls.Add($installMuteButton)

$unmuteButton = New-Object System.Windows.Forms.Button
$unmuteButton.Text = Get-Text 'UnmuteButton'
$unmuteButton.Location = New-Object System.Drawing.Point(196, 120)
$unmuteButton.Size = New-Object System.Drawing.Size(130, 36)
$form.Controls.Add($unmuteButton)

$openAppButton = New-Object System.Windows.Forms.Button
$openAppButton.Text = Get-Text 'OpenAppButton'
$openAppButton.Location = New-Object System.Drawing.Point(336, 120)
$openAppButton.Size = New-Object System.Drawing.Size(130, 36)
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
        switch ($RequestedAction) {
            'InstallMute' { Run-InstallMuteWorkflow }
            'Unmute' { Run-UnmuteWorkflow }
            'OpenApp' { Run-OpenAppWorkflow }
        }
        [System.Windows.Forms.MessageBox]::Show((Get-Text 'Completed'), (Get-Text 'Title')) | Out-Null
    } catch {
        Write-Log ("{0}: {1}" -f (Get-Text 'Error'), $_.Exception.Message)
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, (Get-Text 'Title')) | Out-Null
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

Write-Log (Get-Text 'Ready')
[void]$form.ShowDialog()
