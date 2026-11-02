@echo off
rem Activate the portable Rust environment for Windows in the CURRENT cmd session.
rem Usage: call windows\env.bat

set "RUST_PORTABLE_WINDOWS_DIR=%~dp0"
if "%RUST_PORTABLE_WINDOWS_DIR:~-1%"=="\" set "RUST_PORTABLE_WINDOWS_DIR=%RUST_PORTABLE_WINDOWS_DIR:~0,-1%"
for %%I in ("%RUST_PORTABLE_WINDOWS_DIR%\..") do set "RUST_PORTABLE_HOME=%%~fI"

set "ROOT_NO_SPACES=%RUST_PORTABLE_HOME: =%"
if not "%ROOT_NO_SPACES%"=="%RUST_PORTABLE_HOME%" (
    echo [rust-portable] ERROR: the package path contains spaces.
    echo [rust-portable] Current path: %RUST_PORTABLE_HOME%
    echo [rust-portable] Move the whole package to a path without spaces, for example D:\rust-portable.
    exit /b 1
)

set "CARGO_HOME=%RUST_PORTABLE_WINDOWS_DIR%\cargo"
set "RUSTUP_HOME=%RUST_PORTABLE_WINDOWS_DIR%\rustup"
set "MINGW_HOME=%RUST_PORTABLE_WINDOWS_DIR%\toolchain\mingw64"
set "RUST_PORTABLE_SHARED=%RUST_PORTABLE_HOME%\shared"

rem Avoid growing PATH when this file is called repeatedly in one shell.
if /I not "%RUST_PORTABLE_ENV%"=="%RUST_PORTABLE_WINDOWS_DIR%" (
    set "PATH=%CARGO_HOME%\bin;%MINGW_HOME%\bin;%PATH%"
    set "RUST_PORTABLE_ENV=%RUST_PORTABLE_WINDOWS_DIR%"
)

if not exist "%CARGO_HOME%\bin\rustc.exe" (
    echo [rust-portable] ERROR: windows\cargo\bin\rustc.exe was not found.
    echo [rust-portable] The package is incomplete or was moved incorrectly.
    exit /b 1
)

if not exist "%RUSTUP_HOME%\toolchains\stable-x86_64-pc-windows-gnu\bin\rustc.exe" (
    echo [rust-portable] ERROR: the bundled stable Windows Rust toolchain was not found.
    echo [rust-portable] The package is incomplete.
    exit /b 1
)

if not exist "%MINGW_HOME%\bin\gcc.exe" (
    echo [rust-portable] ERROR: MinGW gcc.exe was not found.
    echo [rust-portable] The package is incomplete.
    exit /b 1
)

echo [rust-portable] Windows environment activated: %RUST_PORTABLE_HOME%
exit /b 0
