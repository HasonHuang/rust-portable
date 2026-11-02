@echo off
setlocal EnableExtensions

set "NOPAUSE=%~1"
set "FAIL=0"

call "%~dp0env.bat"
if errorlevel 1 goto :failed

echo ============================================================
echo  Rust Portable - Windows environment check
echo ============================================================
echo  Package     : %RUST_PORTABLE_HOME%
echo  CARGO_HOME  : %CARGO_HOME%
echo  RUSTUP_HOME : %RUSTUP_HOME%
echo  MinGW       : %MINGW_HOME%
echo  Shared      : %RUST_PORTABLE_SHARED%
echo ============================================================
echo.

echo [check] rustc
rustc --version
if errorlevel 1 set "FAIL=1"

echo [check] cargo
cargo --version
if errorlevel 1 set "FAIL=1"

echo [check] rustfmt
rustfmt --version
if errorlevel 1 set "FAIL=1"

echo [check] clippy
cargo clippy --version
if errorlevel 1 set "FAIL=1"

echo [check] rust-analyzer
rust-analyzer --version
if errorlevel 1 set "FAIL=1"

echo [check] gcc
gcc --version
if errorlevel 1 set "FAIL=1"

echo [check] g++
g++ --version
if errorlevel 1 set "FAIL=1"

echo.
echo [check] shared files...
if not exist "%RUST_PORTABLE_SHARED%\examples\hello\Cargo.toml" (
    echo Missing: shared\examples\hello\Cargo.toml
    set "FAIL=1"
)
if not exist "%RUST_PORTABLE_SHARED%\tests\smoke.c" (
    echo Missing: shared\tests\smoke.c
    set "FAIL=1"
)

echo.
echo [check] building a temporary Rust project...
set "TDIR=%TEMP%\rust-portable-doctor-%RANDOM%-%RANDOM%"
mkdir "%TDIR%" >nul 2>&1
if errorlevel 1 goto :temp_failed

cargo new --quiet --vcs none --name doctor "%TDIR%\doctor"
if errorlevel 1 goto :rust_build_failed

pushd "%TDIR%\doctor"
cargo run --quiet
if errorlevel 1 set "FAIL=1"
popd

echo [check] compiling a temporary C program...
gcc "%RUST_PORTABLE_SHARED%\tests\smoke.c" -o "%TDIR%\smoke.exe"
if errorlevel 1 set "FAIL=1"
if exist "%TDIR%\smoke.exe" "%TDIR%\smoke.exe"

rmdir /s /q "%TDIR%" >nul 2>&1

if "%FAIL%"=="1" goto :failed
echo.
echo [rust-portable] All checks passed.
set "RC=0"
goto :finish

:rust_build_failed
echo [rust-portable] Failed to create or build the temporary Rust project.
rmdir /s /q "%TDIR%" >nul 2>&1
set "FAIL=1"
set "RC=1"
goto :finish

:temp_failed
echo [rust-portable] Failed to create a temporary directory under %TEMP%.
set "RC=1"
goto :finish

:failed
echo.
echo [rust-portable] One or more checks failed.
set "RC=1"

:finish
if /I "%NOPAUSE%"=="--no-pause" exit /b %RC%
echo.
pause
exit /b %RC%
