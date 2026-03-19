# ShutterMute

삼성 기본 카메라 셔터음을 Windows에서 ADB로 처리하는 도구입니다.  
이 포크는 기존 APK 중심 흐름보다, `ShutterMute.exe` 하나로 바로 적용하거나 `SetEdit`를 준비해 두고 폰에서 직접 바꾸는 흐름에 초점을 맞춥니다.

[최신 EXE 다운로드](https://github.com/kkyyuu99/shuttermute/releases/latest/download/ShutterMute.exe)

## 이 저장소의 현재 기준

- 기본 배포 파일은 `ShutterMute.exe`입니다.
- EXE 안에 필요한 ADB 파일이 함께 들어 있으므로, Windows PC에 ADB를 따로 설치하지 않아도 됩니다.
- 기존 Android 앱 소스는 레거시 참고용으로 저장소에 남아 있지만, 현재 기본 사용 흐름은 EXE 기준입니다.
- EXE에는 두 가지 방식이 함께 들어 있습니다.
  - `무음 적용 / 소리 복구`: PC에서 ADB로 바로 값 변경
  - `SetEdit 설치와 권한 부여 / SetEdit 열기`: SetEdit를 준비해 두고 폰에서 직접 값 변경

## 준비물

- Windows PC
- 삼성 USB 드라이버
- USB 케이블
- 휴대폰의 USB 디버깅 활성화
- 휴대폰 RSA 허용 팝업 승인

## 빠른 사용 방법

1. 삼성폰을 USB로 Windows PC에 연결합니다.
2. 휴대폰에서 개발자 옵션과 USB 디버깅을 켭니다.
3. `ShutterMute.exe`를 실행합니다.
4. 시작 시 언어를 선택합니다. 현재 한국어와 일본어를 지원합니다.
5. 아래 네 가지 중 하나를 선택합니다.
   - `카메라 무음 적용`
   - `카메라 소리 복구`
   - `SetEdit 설치와 권한 부여`
   - `SetEdit 열기`
6. 휴대폰에 RSA 승인 팝업이 뜨면 허용하고 계속 진행합니다.

## 두 가지 사용 흐름

### 1. 직접 적용 방식

- `카메라 무음 적용`은 EXE가 ADB로 대상 폰에 바로 명령을 보냅니다.
- `카메라 소리 복구`는 같은 경로로 값을 원래대로 돌립니다.
- 가장 빠르고 단순하지만, 값을 바꿀 때마다 PC와 ADB 연결이 필요합니다.

### 2. SetEdit 준비 방식

- `SetEdit 설치와 권한 부여`는 EXE가 공식 `SetEdit v3.0-rc01` APK를 다운로드하고 설치합니다.
- 이어서 `WRITE_SETTINGS`와 `WRITE_SECURE_SETTINGS` 권한을 부여합니다.
- 기본값으로 SetEdit 앱까지 바로 열어 줍니다.
- 이후에는 PC 없이 폰 안에서 SetEdit를 열어 값을 바꿀 수 있어서, 마이너 업데이트 이후나 평소 재적용 때 덜 번거롭습니다.

## 실제로 무음이 되는 과정

이 도구가 하는 핵심은 “삼성 카메라 셔터음 관련 시스템 값”을 바꾸는 것입니다.

### 직접 적용 방식의 순서

1. EXE가 내장된 ADB를 `%LOCALAPPDATA%\ShutterMute\platform-tools`에 풉니다.
2. `adb devices -l`로 연결된 기기를 확인합니다.
3. USB 디버깅과 RSA 승인이 완료된 기기 한 대를 선택합니다.
4. 아래 명령과 같은 방식으로 시스템 값을 변경합니다.

```bash
adb shell settings put system csc_pref_camera_forced_shuttersound_key 0
```

- 값 `0`: 무음
- 값 `1`: 소리 복구

일부 펌웨어에서는 셔터음이 완전히 사라지려면 휴대폰 벨소리 모드도 진동 또는 무음이어야 할 수 있어서, EXE는 가능하면 추가로 진동 모드 전환도 시도합니다.

```bash
adb shell cmd audio set-ringer-mode VIBRATE
```

## SetEdit 방식에서 실제로 하는 일

`SetEdit 설치와 권한 부여`를 선택하면 EXE는 대략 아래 순서로 동작합니다.

1. 공식 GitHub 릴리스에서 `SetEdit-v3.0-rc01.apk`를 다운로드합니다.
2. Android 14+ 설치 제한을 우회하기 위해 아래와 같은 방식으로 설치합니다.

```bash
adb install --bypass-low-target-sdk-block SetEdit-v3.0-rc01.apk
```

3. SetEdit가 시스템 값을 수정할 수 있도록 권한을 부여합니다.

```bash
adb shell appops set io.github.muntashirakon.setedit WRITE_SETTINGS allow
adb shell pm grant io.github.muntashirakon.setedit android.permission.WRITE_SECURE_SETTINGS
```

4. SetEdit 앱을 열어 줍니다.
5. 사용자는 SetEdit 안에서 아래 키를 직접 바꿉니다.

```text
Database: System
Key: csc_pref_camera_forced_shuttersound_key
Value: 0 (무음) / 1 (소리 복구)
```

## 원리 설명

이 방식은 안드로이드 표준 “카메라 셔터음 끄기 API”를 쓰는 것이 아닙니다.  
삼성 펌웨어에서 사용되는 설정 키 `csc_pref_camera_forced_shuttersound_key`를 직접 건드리는 방식입니다.

즉, 핵심 원리는 아래와 같습니다.

1. 삼성 펌웨어가 참조하는 특정 설정 키가 있다.
2. 그 키 값을 `0` 또는 `1`로 바꾸면 카메라 셔터음 동작이 달라진다.
3. EXE 직접 방식은 ADB가 그 값을 바로 바꾼다.
4. SetEdit 방식은 ADB로 한 번 설치와 권한만 준비해 두고, 이후에는 앱 안에서 같은 값을 바꾼다.

중요한 점은 두 방식이 “다른 우회법”이 아니라는 것입니다.  
둘 다 결국 같은 삼성 설정 키를 사용합니다. 따라서 삼성이 이 키를 제거하거나 무시하도록 바꾸면 두 방식 모두 막힐 수 있습니다.

## 업데이트와 유지 가능성

### 마이너 업데이트

- `직접 적용 방식`은 업데이트 후에도 다시 EXE를 실행하면 바로 시도할 수 있습니다.
- `SetEdit 방식`은 앱과 권한이 그대로 살아 있으면 더 편합니다. 폰 안에서 바로 값을 바꾸면 되기 때문입니다.
- 다만 마이너 업데이트라도 권한이 풀리거나 키 동작이 바뀌면 다시 ADB 세팅이 필요할 수 있습니다.

### 메이저 판올림

- Android 메이저 업그레이드나 One UI 큰 판올림에서는 앱 설치 상태, 권한, 키 동작 중 하나 이상이 바뀔 가능성이 더 큽니다.
- 이 경우 `SetEdit`도 다시 설치하거나 권한을 다시 부여해야 할 수 있습니다.
- 가장 중요한 건 “삼성 쪽 키가 여전히 먹는지”입니다. 이게 막히면 직접 방식과 SetEdit 방식이 함께 막힙니다.

## 한계와 주의점

- 이 방식은 삼성 전용 설정 동작에 의존합니다.
- 향후 One UI 또는 Android 업데이트에서 언제든 막힐 수 있습니다.
- 일부 삼성 펌웨어에서는 휴대폰이 진동 또는 무음 모드여야 셔터음이 완전히 사라질 수 있습니다.
- 법률, 규정, 장소 정책, 기기 정책을 준수하는 범위에서만 사용해 주세요.

## CLI 옵션

EXE는 대화형 실행 외에 인자 실행도 지원합니다.

```text
--language ko|ja
--action mute|unmute|setedit-setup|setedit-open
--skip-vibrate
--setedit-apk <path>
--setedit-url <url>
--no-open-setedit
--no-pause
--help
```

예시:

```bash
ShutterMute.exe --language ko --action setedit-setup
ShutterMute.exe --language ko --action mute --skip-vibrate
```

## 면책

- 카메라 셔터음 제어가 허용되는 범위에서만 사용해 주세요.
- 현지 법률, 규정, 장소 정책, 기기 정책 준수 책임은 사용자에게 있습니다.
- 이 저장소와 도구는 어떠한 보증 없이 있는 그대로 제공됩니다.
- 오용, 기기 문제, 데이터 손실, 기타 사용 결과에 대해서 작성자와 유지보수자는 책임지지 않습니다.

## 주요 소스 위치

- [tools/ShutterMuteExe/Program.cs](tools/ShutterMuteExe/Program.cs): 콘솔 진입점과 공통 흐름
- [tools/ShutterMuteExe/SetEditWorkflow.cs](tools/ShutterMuteExe/SetEditWorkflow.cs): SetEdit 다운로드, 설치, 권한 부여 흐름
- [tools/publish-shuttermute-exe.ps1](tools/publish-shuttermute-exe.ps1): EXE 빌드 스크립트
- [tools/ShutterMuteAdbTool.ps1](tools/ShutterMuteAdbTool.ps1): 이전 PowerShell 기반 도구

## 레거시 앱 경로

기존 APK 기반 Android 앱 흐름은 `app/` 아래에 남아 있지만, 이 포크에서는 더 이상 기본 배포 수단이 아닙니다.
