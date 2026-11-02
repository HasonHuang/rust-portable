[CmdletBinding()]
param(
    [string]$Version = '',
    [string]$OutputDir = '',
    [switch]$SkipDoctor,
    [switch]$KeepStaging
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host ''
    Write-Host "[build] $Message"
}

function Copy-Tree {
    param(
        [string]$Source,
        [string]$Destination,
        [string[]]$ExcludeDirs = @()
    )

    if (-not (Test-Path -LiteralPath $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    $roboArgs = @(
        $Source,
        $Destination,
        '/E',
        '/MT:8',
        '/R:1',
        '/W:1',
        '/NFL',
        '/NDL',
        '/NJH',
        '/NJS',
        '/NP'
    )
    if ($ExcludeDirs.Count -gt 0) {
        $roboArgs += '/XD'
        $roboArgs += $ExcludeDirs
    }

    & robocopy @roboArgs | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy failed with exit code $LASTEXITCODE while copying $Source"
    }
    $global:LASTEXITCODE = 0
}

function Get-ToolVersion {
    param(
        [string]$Path,
        [string[]]$ToolArgs = @()
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Path @ToolArgs 2>$null
        if ($LASTEXITCODE -ne 0 -or $null -eq $output) {
            return 'unavailable'
        }
        return ([string]($output | Select-Object -First 1)).Trim()
    }
    catch {
        return 'unavailable'
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$versionFile = Join-Path $repoRoot 'VERSION'

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (Get-Content -LiteralPath $versionFile -Raw).Trim()
}
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Invalid version '$Version'. Use MAJOR.MINOR.PATCH."
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $repoRoot 'dist'
}
$OutputDir = [System.IO.Path]::GetFullPath($OutputDir)

$platform = 'windows-x64'
$assetName = "rust-portable-v$Version-$platform.zip"
$zipPath = Join-Path $OutputDir $assetName
$sumPath = Join-Path $OutputDir 'SHA256SUMS'
$stageRoot = Join-Path $OutputDir '_stage'
$packageRoot = Join-Path $stageRoot 'rust-portable'

$windowsSrc = Join-Path $repoRoot 'windows'
$sharedSrc = Join-Path $repoRoot 'shared'

$required = @(
    (Join-Path $windowsSrc 'cargo\bin\rustc.exe'),
    (Join-Path $windowsSrc 'cargo\bin\cargo.exe'),
    (Join-Path $windowsSrc 'cargo\bin\rustup.exe'),
    (Join-Path $windowsSrc 'rustup\toolchains\stable-x86_64-pc-windows-gnu\bin\rustc.exe'),
    (Join-Path $windowsSrc 'toolchain\mingw64\bin\gcc.exe'),
    (Join-Path $windowsSrc 'doctor.bat'),
    (Join-Path $sharedSrc 'examples\hello\Cargo.toml'),
    (Join-Path $sharedSrc 'tests\smoke.c')
)
foreach ($file in $required) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "The build inputs are incomplete. Missing: $file"
    }
}

Write-Step "Preparing staging directory for v$Version"
if (Test-Path -LiteralPath $stageRoot) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-Step 'Copying Windows toolchain and scripts'
Copy-Tree -Source $windowsSrc -Destination (Join-Path $packageRoot 'windows') -ExcludeDirs @(
    (Join-Path $windowsSrc 'cargo\registry'),
    (Join-Path $windowsSrc 'cargo\git'),
    (Join-Path $windowsSrc 'cargo\.package-cache'),
    (Join-Path $windowsSrc 'rustup\downloads'),
    (Join-Path $windowsSrc 'rustup\tmp')
)

Write-Step 'Copying shared files'
Copy-Tree -Source $sharedSrc -Destination (Join-Path $packageRoot 'shared')

foreach ($name in @('README.md', 'LICENSE', 'CHANGELOG.md')) {
    $source = Join-Path $repoRoot $name
    if (Test-Path -LiteralPath $source -PathType Leaf) {
        Copy-Item -LiteralPath $source -Destination $packageRoot
    }
}

# The release version always equals the Rust version, so write VERSION from the
# version being built instead of copying a possibly stale file from the repo.
$stagedVersionPath = Join-Path $packageRoot 'VERSION'
[System.IO.File]::WriteAllText($stagedVersionPath, "$Version`n", (New-Object System.Text.UTF8Encoding($false)))

$cargoHome = Join-Path $packageRoot 'windows\cargo'
$rustupHome = Join-Path $packageRoot 'windows\rustup'
$mingwHome = Join-Path $packageRoot 'windows\toolchain\mingw64'
$cargoBin = Join-Path $cargoHome 'bin'
$mingwBin = Join-Path $mingwHome 'bin'

$env:CARGO_HOME = $cargoHome
$env:RUSTUP_HOME = $rustupHome
$env:MINGW_HOME = $mingwHome
$env:RUST_PORTABLE_HOME = $packageRoot
$env:RUST_PORTABLE_WINDOWS_DIR = (Join-Path $packageRoot 'windows')
$env:RUST_PORTABLE_SHARED = (Join-Path $packageRoot 'shared')
$env:PATH = "$cargoBin;$mingwBin;$env:PATH"

$rustcVersion = Get-ToolVersion -Path (Join-Path $cargoBin 'rustc.exe') -ToolArgs @('--version')
$cargoVersion = Get-ToolVersion -Path (Join-Path $cargoBin 'cargo.exe') -ToolArgs @('--version')
$rustupVersion = Get-ToolVersion -Path (Join-Path $cargoBin 'rustup.exe') -ToolArgs @('--version')
$gccVersion = Get-ToolVersion -Path (Join-Path $mingwBin 'gcc.exe') -ToolArgs @('--version')

if ($rustcVersion -notmatch '^rustc (\d+\.\d+\.\d+)') {
    throw "Cannot determine the Rust version from '$rustcVersion'. Run scripts\prepare-windows.ps1 first."
}
$rustcSemver = $Matches[1]
if ($rustcSemver -ne $Version) {
    throw "The toolchain reports Rust $rustcSemver, but the release version is $Version. The release version must equal the Rust version."
}

$gitCommit = 'unknown'
try {
    $gitCommit = (& git -C $repoRoot rev-parse --short HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitCommit)) {
        $gitCommit = 'unknown'
    }
}
catch {
    $gitCommit = 'unknown'
}

$builtAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
$buildInfo = @"
rust-portable $Version
Platform: $platform
Rust version: $Version
Built (UTC): $builtAt
Git commit: $gitCommit
Rust target: x86_64-pc-windows-gnu

$rustcVersion
$cargoVersion
$rustupVersion
$gccVersion
"@
$buildInfoPath = Join-Path $packageRoot 'BUILD-INFO.txt'
[System.IO.File]::WriteAllText($buildInfoPath, $buildInfo + "`r`n", (New-Object System.Text.UTF8Encoding($false)))

if (-not $SkipDoctor) {
    Write-Step 'Running the staged environment self-check'
    $doctor = Join-Path $packageRoot 'windows\doctor.bat'
    & $doctor '--no-pause'
    if ($LASTEXITCODE -ne 0) {
        throw "doctor.bat failed with exit code $LASTEXITCODE"
    }
}

Write-Step 'Creating the ZIP archive'
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

$sevenZip = Join-Path $env:ProgramFiles '7-Zip\7z.exe'
if (-not (Test-Path -LiteralPath $sevenZip)) {
    $sevenZip = $null
    if (${env:ProgramFiles(x86)}) {
        $candidate = Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe'
        if (Test-Path -LiteralPath $candidate) { $sevenZip = $candidate }
    }
}

if ($sevenZip) {
    Push-Location $stageRoot
    try {
        & $sevenZip a -tzip -mx=7 -mmt=on -bso0 -bsp0 $zipPath 'rust-portable'
        if ($LASTEXITCODE -ge 2) {
            throw "7-Zip failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}
else {
    $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (-not (Test-Path -LiteralPath $tar)) {
        throw 'No archive tool found. Install 7-Zip or use Windows 10/11 tar.exe.'
    }
    & $tar -a -c -f $zipPath -C $stageRoot 'rust-portable'
    if ($LASTEXITCODE -ne 0) {
        throw "tar.exe failed with exit code $LASTEXITCODE"
    }
}

Write-Step 'Writing SHA256 checksum'
$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
$checksumText = "$hash  $assetName`n"
[System.IO.File]::WriteAllText($sumPath, $checksumText, (New-Object System.Text.UTF8Encoding($false)))

$size = (Get-Item -LiteralPath $zipPath).Length
$sizeMiB = [math]::Round($size / 1MB, 1)

if (-not $KeepStaging) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
}

Write-Host ''
Write-Host '[build] Windows package created.'
Write-Host "  Version : $Version"
Write-Host "  Asset   : $zipPath"
Write-Host "  Size    : $sizeMiB MiB"
Write-Host "  SHA256  : $hash"
Write-Host "  Sums    : $sumPath"
Write-Host ''
