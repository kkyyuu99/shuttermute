# Windows one-click helpers

This folder contains the Windows-side ADB helpers for `ShutterMute`.

Files:

- `ShutterMuteAdbTool.ps1`: PowerShell backend with GUI and headless modes
- `..\ShutterMute-Mute.bat`: double-click to run the legacy PowerShell mute flow
- `..\ShutterMute-Unmute.bat`: double-click to restore shutter sound
- `ShutterMuteExe\`: source for the single-file Windows EXE
- `publish-shuttermute-exe.ps1`: builds a standalone Windows EXE into `build/shuttermute-exe`

Recommended path:

- Use the single-file EXE when you want to move just one file around on Windows.
- The EXE talks to the phone over ADB directly and does not install the legacy Android APK.
- The published EXE can bundle `adb.exe` and the required DLLs inside itself, so the target PC does not need a separate ADB install.
- On first launch, the EXE extracts its bundled ADB files into `%LOCALAPPDATA%\ShutterMute\platform-tools`.

Startup language options:

- Korean
- Japanese

The language list is intentionally limited to markets that are commonly treated as shutter-sound-enforced for Samsung phones: Korea and Japan.

What the single-file EXE does:

1. Finds `adb.exe`
2. Confirms exactly one Android device is connected and authorized
3. Writes `csc_pref_camera_forced_shuttersound_key=0` or `1` through ADB shell
4. Tries to switch the phone to Vibrate mode as a best effort when applying mute

What the legacy PowerShell flow does:

1. Finds `adb.exe`
2. Confirms exactly one Android device is connected and authorized
3. Installs the legacy APK
4. Grants the app's `WRITE_SETTINGS` app-op
5. Writes `csc_pref_camera_forced_shuttersound_key=0` through ADB shell
6. Tries to switch the phone to Vibrate mode as a best effort

Notes:

- If USB debugging is off, the tool pauses and shows Samsung-specific steps before retrying.
- The tool asks for a language when it starts.
- The best-effort vibrate step may not work on every device build.
- If the phone is already connected and authorized, `ShutterMute.exe` is the recommended path.
