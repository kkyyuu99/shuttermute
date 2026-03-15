# camsung One-Click EXE

Primary download: `CamsungOneClick.exe`

한국어 요약:

- Windows에서 삼성 카메라 셔터음을 ADB로 바로 제어하는 원클릭 EXE입니다.
- APK 설치가 필요 없습니다.
- 대상 PC에 ADB를 따로 설치할 필요가 없습니다.
- 시작 시 한국어/일본어를 선택할 수 있습니다.

## Overview

- Windows one-click tool for Samsung camera shutter sound control
- No APK installation required
- No separate ADB installation required on the target PC
- Startup language selection: Korean or Japanese

## Before Use

- Install the Samsung USB driver on the PC
- Enable USB debugging on the phone
- Approve the RSA prompt on the phone when asked

## Notes

- On first launch, the EXE extracts bundled ADB files to `%LOCALAPPDATA%\CamsungOneClick\platform-tools`
- Some Samsung builds may still require Vibrate or Silent mode
- The legacy Android app source remains in the repository, but this release is centered on the standalone Windows EXE

## Disclaimer

- Use only where shutter sound control is lawful and appropriate
- Compliance with local law and venue policy is the user's responsibility
- Provided as-is without warranty
- Future Samsung or Android updates may break this method
