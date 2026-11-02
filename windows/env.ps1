# Activate the portable Rust environment for Windows in the CURRENT PowerShell session.
# Usage (dot-source it):  . .\windows\env.ps1
# Or from any directory: . "D:\rust-portable\windows\env.ps1"

$windowsDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($windowsDir)) {
    throw "env.ps1 must be run from a file (do not paste its contents)."
}

$packageRoot = Split-Path -Parent $windowsDir
if ($packageRoot -match '\s') {
    throw "The package path must not contain spaces. Current path: $packageRoot"
}

$cargoHome = Join-Path $windowsDir 'cargo'
$rustupHome = Join-Path $windowsDir 'rustup'
$mingwHome = Join-Path $windowsDir 'toolchain\mingw64'
$cargoBin = Join-Path $cargoHome 'bin'
$mingwBin = Join-Path $mingwHome 'bin'
$sharedDir = Join-Path $packageRoot 'shared'

$required = @(
    (Join-Path $cargoBin 'rustc.exe'),
    (Join-Path $cargoBin 'cargo.exe'),
    (Join-Path $mingwBin 'gcc.exe')
)
foreach ($item in $required) {
    if (-not (Test-Path -LiteralPath $item -PathType Leaf)) {
        throw "Portable environment is incomplete. Missing: $item"
    }
}

# CI installs a versioned toolchain such as 1.99.1-x86_64-pc-windows-gnu,
# while a local environment may use the stable-* channel alias.
$toolchainRoot = Join-Path $rustupHome 'toolchains'
$toolchainRustc = @(
    Get-ChildItem -LiteralPath $toolchainRoot -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'bin\rustc.exe' } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
)
if ($toolchainRustc.Count -eq 0) {
    throw "Portable environment is incomplete. No Rust toolchain under: $toolchainRoot"
}

$env:RUST_PORTABLE_HOME = $packageRoot
$env:RUST_PORTABLE_WINDOWS_DIR = $windowsDir
$env:RUST_PORTABLE_SHARED = $sharedDir
$env:CARGO_HOME = $cargoHome
$env:RUSTUP_HOME = $rustupHome
$env:MINGW_HOME = $mingwHome
$env:RUST_PORTABLE_ENV = $windowsDir

$keep = foreach ($entry in ($env:Path -split ';')) {
    $value = $entry.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { continue }
    if ($value.TrimEnd('\') -ieq $cargoBin.TrimEnd('\')) { continue }
    if ($value.TrimEnd('\') -ieq $mingwBin.TrimEnd('\')) { continue }
    $value
}
$env:Path = (@($cargoBin, $mingwBin) + @($keep)) -join ';'

Write-Host "[rust-portable] Windows environment activated: $packageRoot"
