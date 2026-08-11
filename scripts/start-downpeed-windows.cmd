@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-downpeed-windows.ps1"
exit /b %ERRORLEVEL%

