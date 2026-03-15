# ShutterMute

삼성 기본 카메라 셔터음을 Windows에서 ADB로 바로 무음 처리하는 원클릭 도구, ShutterMute입니다.

[최신 EXE 다운로드](https://github.com/kkyyuu99/shuttermute/releases/latest/download/ShutterMute.exe)

## 이 저장소의 현재 기준

- 기본 배포 파일은 `ShutterMute.exe`입니다.
- EXE 안에 필요한 ADB 파일이 함께 들어 있으므로, 대상 Windows PC에 ADB를 따로 설치할 필요가 없습니다.
- 현재 원클릭 방식은 예전 Android APK를 설치하지 않아도 됩니다.
- 기존 Android 앱 소스는 레거시 참고용으로 이 저장소에 그대로 유지합니다.

## 준비물

- Windows PC
- 삼성 USB 드라이버
- USB 케이블
- 휴대폰의 USB 디버깅 활성화
- 휴대폰 RSA 허용 팝업 승인

## 사용 방법

1. 삼성폰을 USB로 Windows PC에 연결합니다.
2. 휴대폰에서 개발자 옵션과 USB 디버깅을 켭니다.
3. `ShutterMute.exe`를 실행합니다.
4. 시작 시 언어를 선택합니다. 현재 한국어와 일본어를 지원합니다.
5. `무음 적용` 또는 `소리 복구`를 선택합니다.
6. 휴대폰에 RSA 승인 팝업이 뜨면 허용하고 계속 진행합니다.

## 참고

- 첫 실행 시 EXE 내부의 ADB 파일이 `%LOCALAPPDATA%\ShutterMute\platform-tools`로 풀립니다.
- 일부 삼성 펌웨어에서는 휴대폰이 진동 또는 무음 모드여야 셔터음이 완전히 사라질 수 있습니다.
- 이 방식은 삼성 전용 설정 동작에 의존하므로, 향후 One UI 또는 Android 업데이트에서 막힐 수 있습니다.
- 용도는 반드시 타인에게 피해를 주지 않는 합법적이고 신중한 사용에 한정해 주세요.

## 면책 및 주의사항

- 카메라 셔터음 제어가 허용되는 범위에서만 사용해 주세요.
- 현지 법률, 규정, 장소 정책, 기기 정책 준수 책임은 사용자에게 있습니다.
- 이 저장소와 도구는 어떠한 보증 없이 있는 그대로 제공됩니다.
- 삼성 또는 Android 업데이트로 이 방식이 언제든 막힐 수 있습니다.
- 오용, 기기 문제, 데이터 손실, 기타 사용 결과에 대해서 작성자와 유지보수자는 책임지지 않습니다.

## 주요 소스 위치

- [tools/ShutterMuteExe/Program.cs](tools/ShutterMuteExe/Program.cs): 단일 EXE 소스
- [tools/publish-shuttermute-exe.ps1](tools/publish-shuttermute-exe.ps1): EXE 빌드 스크립트
- [tools/ShutterMuteAdbTool.ps1](tools/ShutterMuteAdbTool.ps1): 이전 PowerShell 기반 도구

## 레거시 앱 경로

기존 APK 기반 Android 앱 흐름은 `app/` 아래에 남아 있지만, 이 포크에서는 더 이상 기본 배포 수단이 아닙니다.
