# ShutterMute 배포 파일

기본 다운로드 파일:

- `ShutterMute.exe`
- `ShutterMute-PhoneBridge.apk`

## 개요

- Windows에서 삼성 카메라 셔터음을 ADB로 바로 무음 처리하는 원클릭 EXE입니다.
- Android 폰이 다른 Android 폰에 무선 디버깅으로 연결해 무음/복구를 수행하는 `Phone Bridge` APK도 함께 배포합니다.
- EXE는 APK 설치가 필요 없고, 대상 PC에 ADB를 따로 설치할 필요가 없습니다.
- Phone Bridge는 대상 폰의 무선 디버깅 정보(IP, pairing port, connect port, pairing code)가 필요합니다.

## 사용 전 준비

- PC에 삼성 USB 드라이버를 설치해 주세요.
- 휴대폰에서 USB 디버깅을 켜 주세요.
- 휴대폰에 표시되는 RSA 허용 팝업을 승인해 주세요.
- Phone Bridge를 사용할 경우, 두 폰이 같은 네트워크에 있어야 하며 대상 폰에서 무선 디버깅을 켜야 합니다.

## 참고

- 첫 실행 시 EXE 내부의 ADB 파일이 `%LOCALAPPDATA%\ShutterMute\platform-tools`로 풀립니다.
- 일부 삼성 펌웨어에서는 진동 또는 무음 모드가 필요할 수 있습니다.
- Phone Bridge 버전은 다른 폰이 ADB 호스트 역할을 대신하는 방식이라, 컴퓨터 없이도 다른 폰을 통해 대상 폰에 연결할 수 있습니다.

## 면책 및 주의사항

- 카메라 셔터음 제어가 합법적이고 적절한 범위에서만 사용해 주세요.
- 현지 법률과 장소 정책 준수 책임은 사용자에게 있습니다.
- 이 도구는 어떠한 보증 없이 제공됩니다.
- 향후 삼성 또는 Android 업데이트로 동작이 막힐 수 있습니다.
