@echo off
setlocal EnableExtensions

set "PLATFORM_DIR=%~dp0"
if "%PLATFORM_DIR:~-1%"=="\" set "PLATFORM_DIR=%PLATFORM_DIR:~0,-1%"
for %%I in ("%PLATFORM_DIR%\..") do set "ROOT=%%~fI"

echo [rust-portable] Removing Windows user environment variables...
echo [rust-portable] Package: %ROOT%
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install-env.ps1" -PlatformDir "%PLATFORM_DIR%" -Remove
set "RC=%ERRORLEVEL%"

echo.
if not "%RC%"=="0" (
    echo [rust-portable] FAILED. See the error above.
    if /I not "%~1"=="--no-pause" pause
    exit /b %RC%
)

echo [rust-portable] Windows user environment cleaned. The files were NOT deleted.
echo [rust-portable] Open a new terminal for the change to take effect.
if /I not "%~1"=="--no-pause" pause
exit /b 0
