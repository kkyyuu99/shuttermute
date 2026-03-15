@echo off
setlocal
chcp 65001 >nul
set SCRIPT_DIR=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%tools\ShutterMuteAdbTool.ps1" -NoGui -PauseOnExit -Action InstallMute -TrySetVibrateMode
