# 수정표

포멧은 [Keep a Changelog][keep-a-changelog]를 기반으로 합니다.

[keep-a-changelog]: https://keepachangelog.com/en/1.0.0/

# [미출시]

[미출시]: https://github.com/kkyyuu99/shuttermute/compare/v1.7.1...HEAD

# [1.7.1] - 2026-03-22

## 수정

- `ShutterMute Phone Bridge`에서 페어링 팝업 포트와 무선 디버깅 메인 화면 포트의 뜻을 각각 따로 설명하도록 명칭과 안내 문구를 정리
- Phone Bridge에 예시 값, 입력칸별 오류 표시, 페어링/연결 실패 시 더 직접적인 원인 안내를 추가

[1.7.1]: https://github.com/kkyyuu99/shuttermute/compare/v1.7.0...v1.7.1

# [1.7.0] - 2026-03-22

## 추가

- `ShutterMute Phone Bridge`에 같은 휴대폰에서 다시 연결할 수 있는 셀프 무선 디버깅 모드 추가
- 보안, 휴대전화 정보, 개발자 옵션, Wi-Fi로 바로 이동할 수 있는 인앱 설정 가이드와 바로가기 추가

## 수정

- 셀프 모드에서 현재 휴대폰 IP를 자동 감지해 Phone Bridge 입력 과정을 더 단순하게 정리

[1.7.0]: https://github.com/kkyyuu99/shuttermute/compare/v1.6.1...v1.7.0

# [1.6.1] - 2026-03-22

## 수정

- GitHub Actions에서 전용 keystore로 Phone Bridge APK를 서명해 릴리스 빌드가 안정적으로 완료되도록 수정
- 로컬 Phone Bridge APK 빌드 시 keystore가 없으면 debug keystore를 자동 생성하도록 수정

[1.6.1]: https://github.com/kkyyuu99/shuttermute/compare/v1.6.0...v1.6.1

# [1.6.0] - 2026-03-22

## 추가

- 다른 안드로이드 폰이 무선 디버깅 호스트가 되어 대상 폰을 페어링하고 무음/복구를 실행하는 `ShutterMute Phone Bridge` APK 추가
- GitHub 릴리스에 `ShutterMute.exe`와 `ShutterMute-PhoneBridge.apk`를 함께 배포하는 자동화 추가

## 수정

- README와 릴리스 노트에 Phone Bridge 사용 방법과 두 배포물 구조를 반영

[1.6.0]: https://github.com/kkyyuu99/shuttermute/compare/v1.5.0...v1.6.0

# [1.5.0] - 2026-03-20

## 추가

- Windows EXE에 `SetEdit 설치와 권한 부여`, `SetEdit 열기` 작업 추가
- `setedit-setup`, `setedit-open`, `--setedit-apk`, `--setedit-url` 같은 EXE CLI 인자 추가

## 수정

- README에 직접 ADB 방식과 SetEdit 방식의 차이, 실제 무음 처리 과정, 동작 원리, 업데이트 시 유지 가능성을 자세히 설명

[1.5.0]: https://github.com/kkyyuu99/shuttermute/compare/v1.4.1...v1.5.0

# [1.2.1] - 2025-10-09

## 수정

- LTS 버전 JDK를 사용하지 않아 발생한 빌드 문제 수정

[1.2.1]: https://github.com/ericswpark/camsung/compare/1.2.0...1.2.1

# [1.2.0] - 2025-10-08

## 추가

- 음소거 설정이 토글될 때 카메라가 자동으로 실행되도록 하는 설정 옵션 추가

## 수정

- 적용되는 안드로이드 버전에서 뒤로 탐색 예측 제스처(Predictive back gestures)와 동반되는 에니메이션 지원
- 라이브러리 버전 업데이트

[1.2.0]: https://github.com/ericswpark/camsung/compare/1.1.2...1.2.0

# [1.1.2] - 2025-05-19

## 수정

- 앱 바로가기를 사용하여 카메라 무음을 활성화하거나 비활성화할 경우 갤럭시 루틴 등을 통한 자동화가 더 편리하게 이루어지도록 어플이 종료되게 변경
- Tasker와 같은 어플에서 Broadcast Receiver에 인텐트를 보낼 수 있도록 수정. 이미 만들어진 task XML 파일들은 README를 참조해주세요

[1.1.2]: https://github.com/ericswpark/camsung/compare/1.1.1...1.1.2

# [1.1.1] - 2025-04-29

## 수정

- IzzyOnDroid에 등재하기 위해 라이브러리 메타데이터 추가 절차 비활성화

[1.1.1]: https://github.com/ericswpark/camsung/compare/1.1.0...1.1.1

# [1.1.0] - 2025-04-28

## 추가

- 앱 바로가기와 인텐트가 추가되었습니다! 카메라 무음 설정을 갤럭시 루틴이나 Tasker로 자동화할 수 있습니다.

## 수정

- 새로운 앱 아이콘, 색상표 수정
- 전반적인 코드 정리
- 권한 확인 강화 및 제대로 된 상태 업데이트
- 구 라이브러리 업데이트
- 윈도우 모드에서 올바른 창 크기로 표시되도록 화면 회전 활성화됨
- 낮은 SDK 버전 때문에 앱 표시 비율이 고정된 문제 해결

[1.1.0]: https://github.com/ericswpark/camsung/compare/1.0.3...1.1.0

# [1.0.3] - 2023-03-12

## 수정

- 권한이 주어졌음에도 불구하고 부팅 시 권한이 부족하다는 오류 메시지 수정
- 캠성을 통해 서드파티 어플들이 카메라를 무음시킬 수도 있는 인텐트 체크 수정
- 전반적인 코드 정리

# [1.0.2] - 2021-02-02

## 수정

- 색상표 수정

# [1.0.1] - 2021-02-01

## 수정

- 설정이 존재하지 않을 경우의 크래시 수정

# [1.0.0] - 2021-02-01

최초 출시

[1.0.3]: https://github.com/ericswpark/camsung/compare/1.0.2...1.0.3
[1.0.2]: https://github.com/ericswpark/camsung/compare/1.0.1...1.0.2
[1.0.1]: https://github.com/ericswpark/camsung/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/ericswpark/camsung/compare/509b2f1e5b6dbbee4b2436d20d0b61c04de728bc...1.0.0
