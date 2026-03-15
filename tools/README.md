# Windows one-click helpers

This folder contains a Windows-side ADB helper for `camsung`.

Files:

- `CamsungAdbTool.ps1`: PowerShell backend with GUI and headless modes
- `..\OneClick-InstallMute.bat`: double-click to install the APK and set camera mute
- `..\OneClick-Unmute.bat`: double-click to restore shutter sound

What the install + mute flow does:

1. Finds `adb.exe`
2. Confirms exactly one Android device is connected and authorized
3. Installs `app/build/outputs/apk/release/app-release.apk` with `--bypass-low-target-sdk-block`
4. Grants the app's `WRITE_SETTINGS` app-op
5. Writes `csc_pref_camera_forced_shuttersound_key=0` through ADB shell
6. Tries to switch the phone to Vibrate mode as a best effort

Notes:

- The phone still needs USB debugging enabled.
- The best-effort vibrate step may not work on every device build.
- If the phone is already connected and authorized, `OneClick-InstallMute.bat` is the fastest path.
