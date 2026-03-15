# camsung

Windows one-click tool for controlling the Samsung camera shutter sound over ADB.

<div align="center">

[Korean Guide](README.ko.md)

</div>

[Download latest EXE](https://github.com/kkyyuu99/camsung/releases/latest/download/CamsungOneClick.exe)

## What This Repo Ships Now

- `CamsungOneClick.exe` is the primary release artifact.
- The EXE includes the ADB files it needs, so the target Windows PC does not need a separate ADB install.
- You do not need to install the old Android APK to use the current one-click workflow.
- The original Android app source is still kept in this repository for reference and legacy use.

## Requirements

- Windows PC
- Samsung USB driver installed
- USB cable
- USB debugging enabled on the phone
- Approval of the RSA prompt on the phone

## How To Use

1. Connect the Samsung phone to the Windows PC with USB.
2. Enable Developer options and USB debugging on the phone.
3. Run `CamsungOneClick.exe`.
4. Choose a language: Korean or Japanese.
5. Choose `Mute` to silence the shutter or `Unmute` to restore it.
6. If the phone shows an RSA authorization prompt, approve it and continue.

## Notes

- On first launch, the EXE extracts its bundled ADB files into `%LOCALAPPDATA%\CamsungOneClick\platform-tools`.
- Some Samsung builds may still require the phone to be in Vibrate or Silent mode.
- This workflow relies on Samsung-specific settings behavior and may stop working on future One UI or Android updates.
- This tool is intended only for considerate, lawful use.

## Disclaimer

- Use this tool only where you are legally allowed to control the camera shutter sound.
- You are responsible for complying with local laws, regulations, venue rules, and device policies.
- This repository is provided as-is without warranty.
- Samsung or Android updates may break this method at any time.
- The authors and maintainers are not responsible for misuse, device issues, data loss, or any consequences caused by using this tool.

## Source Layout

- [tools/CamsungOneClickExe/Program.cs](tools/CamsungOneClickExe/Program.cs): single-file EXE source
- [tools/publish-oneclick-exe.ps1](tools/publish-oneclick-exe.ps1): publish script
- [tools/CamsungAdbTool.ps1](tools/CamsungAdbTool.ps1): legacy PowerShell helper

## Legacy App Path

The old APK-based Android app flow is still in the repository under `app/`, but it is no longer the primary download for this fork.
