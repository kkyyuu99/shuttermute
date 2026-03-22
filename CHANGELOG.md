# Changelog

<div align="center">

[한국어][korean-translation]

</div>

The format is based on [Keep a Changelog][keep-a-changelog].

[korean-translation]: CHANGELOG.ko.md
[keep-a-changelog]: https://keepachangelog.com/en/1.0.0/

# [Unreleased]

[Unreleased]: https://github.com/kkyyuu99/shuttermute/compare/v1.7.0...HEAD

# [1.7.0] - 2026-03-22

## Added

- Added a self wireless debugging mode to `ShutterMute Phone Bridge` so the same Android phone can reconnect without a separate terminal app
- Added in-app setup guidance and settings shortcuts for security, phone info, developer options, and Wi-Fi

## Changed

- Simplified the Phone Bridge flow by auto-detecting the current phone IP in self mode

[1.7.0]: https://github.com/kkyyuu99/shuttermute/compare/v1.6.1...v1.7.0

# [1.6.1] - 2026-03-22

## Fixed

- Fixed the Phone Bridge release pipeline by signing the APK with a dedicated keystore in GitHub Actions
- Made local Phone Bridge APK builds create a debug keystore automatically when one is missing

[1.6.1]: https://github.com/kkyyuu99/shuttermute/compare/v1.6.0...v1.6.1

# [1.6.0] - 2026-03-22

## Added

- Added a `ShutterMute Phone Bridge` APK that lets one Android phone pair with and control another phone over Wireless debugging
- Added release automation so GitHub releases now ship both `ShutterMute.exe` and `ShutterMute-PhoneBridge.apk`

## Changed

- Updated the README and release notes to explain the two-distribution model and the Phone Bridge workflow

[1.6.0]: https://github.com/kkyyuu99/shuttermute/compare/v1.5.0...v1.6.0

# [1.5.0] - 2026-03-20

## Added

- Added `SetEdit setup` and `Open SetEdit` actions to the Windows EXE
- Added EXE CLI options such as `setedit-setup`, `setedit-open`, `--setedit-apk`, and `--setedit-url`

## Changed

- Expanded the README with a detailed explanation of the direct ADB flow, the SetEdit flow, how the mute change works, and what can break across updates

[1.5.0]: https://github.com/kkyyuu99/shuttermute/compare/v1.4.1...v1.5.0

# [1.2.1] - 2025-10-09

## Changed

- Fixed build issues with non-LTS version of JDK

[1.2.1]: https://github.com/ericswpark/camsung/compare/1.2.0...1.2.1

# [1.2.0] - 2025-10-08

## Added

- Added a settings option to automatically launch the camera when the mute setting is toggled

## Changed

- The app now supports predictive back gestures and accompanying animations on supported Android versions
- Updated library dependencies

[1.2.0]: https://github.com/ericswpark/camsung/compare/1.1.2...1.2.0

# [1.1.2] - 2025-05-19

## Changed

- App shortcuts now cause the app to exit after muting or unmuting the camera, for ease of automation with Galaxy Routines
- You can now send intents to the Broadcast Receiver from any app, such as Tasker. Please refer to the README for pre-made task XML files

[1.1.2]: https://github.com/ericswpark/camsung/compare/1.1.1...1.1.2

# [1.1.1] - 2025-04-29

## Changed

- Dependency metadata injection was disabled for inclusion into IzzyOnDroid

[1.1.1]: https://github.com/ericswpark/camsung/compare/1.1.0...1.1.1

# [1.1.0] - 2025-04-28

## Added

- App shortcuts and intents have been added! You can now automate the camera mute setting with Galaxy Routines or Tasker.

## Changed

- New app icon and color scheme
- General code cleanup
- Better permissions check and state updating
- Updated library dependencies
- Screen rotations are now enabled for proper window proportions in windowed mode
- Fixed the app ratio not being resizable due to the low build SDK version

[1.1.0]: https://github.com/ericswpark/camsung/compare/1.0.3...1.1.0

# [1.0.3] - 2023-03-12

## Changed

- Fixed error message about insufficient permissions on boot, even when permissions have been granted
- Fixed an intent check that could allow third-party apps to silence the camera through camsung
- General code cleanup

# [1.0.2] - 2021-02-02

## Changed

- Changed color scheme

# [1.0.1] - 2021-02-01

## Changed

- Fixes crash if the prop does not exist

# [1.0.0] - 2021-02-01

Initial release

[1.0.3]: https://github.com/ericswpark/camsung/compare/1.0.2...1.0.3
[1.0.2]: https://github.com/ericswpark/camsung/compare/1.0.1...1.0.2
[1.0.1]: https://github.com/ericswpark/camsung/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/ericswpark/camsung/compare/509b2f1e5b6dbbee4b2436d20d0b61c04de728bc...1.0.0
