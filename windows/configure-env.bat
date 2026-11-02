@echo off
setlocal EnableExtensions

set "PLATFORM_DIR=%~dp0"
if "%PLATFORM_DIR:~-1%"=="\" set "PLATFORM_DIR=%PLATFORM_DIR:~0,-1%"
for %%I in ("%PLATFORM_DIR%\..") do set "ROOT=%%~fI"

set "ROOT_NO_SPACES=%ROOT: =%"
if not "%ROOT_NO_SPACES%"=="%ROOT%" (
    echo [rust-portable] ERROR: the package path contains spaces.
    echo [rust-portable] Current path: %ROOT%
    echo [rust-portable] Move the whole package to a path without spaces, for example D:\rust-portable.
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)

echo [rust-portable] Configuring Windows user environment variables...
echo [rust-portable] Package: %ROOT%
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install-env.ps1" -PlatformDir "%PLATFORM_DIR%"
set "RC=%ERRORLEVEL%"

echo.
if not "%RC%"=="0" (
    echo [rust-portable] FAILED. See the error above.
    if /I not "%~1"=="--no-pause" pause
    exit /b %RC%
)

echo [rust-portable] Done. Open a NEW terminal and run: rustc --version
echo [rust-portable] You can also double-click windows\open-shell.bat.
if /I not "%~1"=="--no-pause" pause
exit /b 0
