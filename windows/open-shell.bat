@echo off
setlocal EnableExtensions

call "%~dp0env.bat"
if errorlevel 1 (
    echo.
    pause
    exit /b 1
)

set "TARGET=%~1"
if not defined TARGET set "TARGET=%USERPROFILE%"

if not exist "%TARGET%\" (
    echo [rust-portable] Directory not found: %TARGET%
    echo.
    pause
    exit /b 1
)

pushd "%TARGET%" 2>nul
if errorlevel 1 (
    echo [rust-portable] Cannot enter directory: %TARGET%
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Rust Portable Shell (Windows)
echo ============================================================
echo  Package     = %RUST_PORTABLE_HOME%
echo  CARGO_HOME  = %CARGO_HOME%
echo  RUSTUP_HOME = %RUSTUP_HOME%
echo  MinGW       = %MINGW_HOME%
echo  Shared      = %RUST_PORTABLE_SHARED%
echo  Directory   = %CD%
echo ------------------------------------------------------------
echo  Try: rustc --version
echo       cargo run --manifest-path "%RUST_PORTABLE_SHARED%\examples\hello\Cargo.toml"
echo  Type "exit" to close this window.
echo ============================================================
echo.

cmd /k
popd
endlocal
