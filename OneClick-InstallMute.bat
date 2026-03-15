@echo off
setlocal
set SCRIPT_DIR=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%tools\CamsungAdbTool.ps1" -NoGui -Action InstallMute -TrySetVibrateMode
echo.
if errorlevel 1 (
  echo The one-click mute workflow failed.
) else (
  echo The one-click mute workflow finished.
)
pause
