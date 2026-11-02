[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repoRoot = Split-Path -Parent $PSScriptRoot
$windowsPath = Join-Path $repoRoot 'windows'
$cargoHome = Join-Path $windowsPath 'cargo'
$rustupHome = Join-Path $windowsPath 'rustup'
$mingwHome = Join-Path $windowsPath 'toolchain\mingw64'
$bootstrapDir = Join-Path $windowsPath 'bootstrap'
$rustupInit = Join-Path $bootstrapDir 'rustup-init.exe'

$rustupInitUrl = 'https://static.rust-lang.org/rustup/archive/1.29.2/x86_64-pc-windows-gnu/rustup-init.exe'
$rustupInitSha256 = 'd2845ad914acf5add202100c0a7ddf19ab1c3e52521e12841bafff13888e49bb'

$winlibsUrl = 'https://github.com/brechtsanders/winlibs_mingw/releases/download/16.2.0posix-14.0.0-msvcrt-r2/winlibs-x86_64-posix-seh-gcc-16.2.0-mingw-w64msvcrt-14.0.0-r2.zip'
$winlibsSha256 = '1b90ec73c96e6905a913746b56fb6b20122422787029810d3afc6a3b440f2322'
$winlibsZip = Join-Path $env:TEMP 'winlibs-16.2.0posix-14.0.0-msvcrt-r2.zip'

function Assert-Sha256 {
    param(
        [string]$Path,
        [string]$Expected
    )

    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Expected.ToLowerInvariant()) {
        throw "SHA256 mismatch for $Path. Expected $Expected, got $actual."
    }
}

New-Item -ItemType Directory -Path $bootstrapDir -Force | Out-Null
New-Item -ItemType Directory -Path $cargoHome -Force | Out-Null
New-Item -ItemType Directory -Path $rustupHome -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $windowsPath 'toolchain') -Force | Out-Null

if (-not (Test-Path -LiteralPath $rustupInit -PathType Leaf)) {
    Write-Host '[prepare] Downloading rustup-init.exe'
    Invoke-WebRequest -Uri $rustupInitUrl -OutFile $rustupInit -UseBasicParsing
}
Assert-Sha256 -Path $rustupInit -Expected $rustupInitSha256

$env:CARGO_HOME = $cargoHome
$env:RUSTUP_HOME = $rustupHome

Write-Host '[prepare] Installing Rust 1.99.1 for x86_64-pc-windows-gnu'
& $rustupInit -y --no-modify-path --profile minimal --default-host x86_64-pc-windows-gnu --default-toolchain 1.99.1-x86_64-pc-windows-gnu
if ($LASTEXITCODE -ne 0) {
    throw "rustup-init failed with exit code $LASTEXITCODE"
}

$rustup = Join-Path $cargoHome 'bin\rustup.exe'
Write-Host '[prepare] Adding components'
& $rustup component add rustfmt clippy rust-analyzer rust-src --toolchain 1.99.1-x86_64-pc-windows-gnu
if ($LASTEXITCODE -ne 0) {
    throw "rustup component add failed with exit code $LASTEXITCODE"
}

Write-Host '[prepare] Downloading WinLibs MinGW-w64'
Invoke-WebRequest -Uri $winlibsUrl -OutFile $winlibsZip -UseBasicParsing
Assert-Sha256 -Path $winlibsZip -Expected $winlibsSha256

Write-Host '[prepare] Extracting WinLibs MinGW-w64'
Expand-Archive -LiteralPath $winlibsZip -DestinationPath (Join-Path $windowsPath 'toolchain') -Force
Remove-Item -LiteralPath $winlibsZip -Force

if (-not (Test-Path -LiteralPath (Join-Path $mingwHome 'bin\gcc.exe') -PathType Leaf)) {
    throw "MinGW extraction failed. Missing: $(Join-Path $mingwHome 'bin\gcc.exe')"
}

Write-Host '[prepare] Toolchain is ready.'
