[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PlatformDir,

    [switch]$Remove
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-NormalizedEntry {
    param([string]$Entry)

    if ([string]::IsNullOrWhiteSpace($Entry)) { return $null }

    $value = $Entry.Trim().Trim('"')
    if ($value.Length -eq 0) { return $null }

    # Preserve drive roots such as "C:\" instead of turning them into "C:".
    if ($value -match '^[A-Za-z]:\\?$') {
        return $value.Substring(0, 2) + '\'
    }
    return $value.TrimEnd('\')
}

function Test-SamePath {
    param([string]$A, [string]$B)

    $left = Get-NormalizedEntry -Entry $A
    $right = Get-NormalizedEntry -Entry $B
    if ($null -eq $left -or $null -eq $right) { return $false }

    return [string]::Equals($left, $right, [StringComparison]::OrdinalIgnoreCase)
}

function Test-PathInside {
    param([string]$Value, [string]$Base)

    $item = Get-NormalizedEntry -Entry $Value
    $parent = Get-NormalizedEntry -Entry $Base
    if ($null -eq $item -or $null -eq $parent) { return $false }
    if ([string]::Equals($item, $parent, [StringComparison]::OrdinalIgnoreCase)) { return $true }

    $prefix = if ($parent.EndsWith('\')) { $parent } else { $parent + '\' }
    return $item.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}

function Get-UserValue {
    param([string]$Name)
    return [Environment]::GetEnvironmentVariable($Name, 'User')
}

function Set-UserValue {
    param([string]$Name, [string]$Value)
    [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
}

function Get-UserPathEntries {
    $raw = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    return @($raw -split ';')
}

function Set-UserPathEntries {
    param([string[]]$Entries)

    $value = $Entries -join ';'
    if ($value.Length -gt 30000) {
        throw "The user PATH would exceed 30000 characters. Remove unused entries from PATH and try again."
    }
    [Environment]::SetEnvironmentVariable('Path', $value, 'User')
}

function Remove-PathEntries {
    param([string[]]$Entries, [string[]]$RemovePaths)

    $kept = New-Object System.Collections.Generic.List[string]
    foreach ($entry in $Entries) {
        $normalized = Get-NormalizedEntry -Entry $entry
        if ($null -eq $normalized) { continue }

        $drop = $false
        foreach ($candidate in $RemovePaths) {
            if (Test-SamePath -A $normalized -B $candidate) {
                $drop = $true
                break
            }
        }
        if (-not $drop) { $kept.Add($normalized) }
    }
    return $kept.ToArray()
}

function Send-EnvironmentChange {
    try {
        if (-not ('RustPortable.NativeMethods' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace RustPortable {
    public static class NativeMethods {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
            uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
    }
}
'@
        }

        $result = [UIntPtr]::Zero
        [RustPortable.NativeMethods]::SendMessageTimeout(
            [IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment',
            2, 5000, [ref]$result) | Out-Null
    }
    catch {
        # New processes still read the registry; broadcasting is only a convenience.
    }
}

$windowsPath = [System.IO.Path]::GetFullPath($PlatformDir)
if (-not (Test-Path -LiteralPath $windowsPath -PathType Container)) {
    throw "Directory not found: $windowsPath"
}
$windowsPath = (Get-Item -LiteralPath $windowsPath).FullName
if ($windowsPath.Length -gt 3) { $windowsPath = $windowsPath.TrimEnd('\') }

$packageRoot = Split-Path -Parent $windowsPath
if ($packageRoot.Length -gt 3) { $packageRoot = $packageRoot.TrimEnd('\') }

if (-not $Remove -and $packageRoot -match '\s') {
    throw "The package path must not contain spaces. Current path: $packageRoot"
}

$cargoHome  = Join-Path $windowsPath 'cargo'
$rustupHome = Join-Path $windowsPath 'rustup'
$mingwHome  = Join-Path $windowsPath 'toolchain\mingw64'
$cargoBin   = Join-Path $cargoHome 'bin'
$mingwBin   = Join-Path $mingwHome 'bin'
$sharedDir  = Join-Path $packageRoot 'shared'

if (-not $Remove) {
    $required = @(
        (Join-Path $cargoBin 'rustc.exe'),
        (Join-Path $cargoBin 'cargo.exe'),
        (Join-Path $cargoBin 'rustup.exe'),
        (Join-Path $mingwBin 'gcc.exe'),
        (Join-Path $sharedDir 'examples\hello\Cargo.toml'),
        (Join-Path $sharedDir 'tests\smoke.c')
    )
    foreach ($file in $required) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            throw "The portable package is incomplete. Missing: $file"
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
        throw "The portable package is incomplete. No Rust toolchain under: $toolchainRoot"
    }
}

$oldMarker = Get-UserValue -Name 'RUST_PORTABLE_HOME'
$oldCargoHome = Get-UserValue -Name 'CARGO_HOME'
$oldRustupHome = Get-UserValue -Name 'RUSTUP_HOME'
$oldMingwHome = Get-UserValue -Name 'MINGW_HOME'

# Remove the current Windows entries. Also remove paths from the old flat
# layout (toolchain at package root) and from a previous package location.
$removePaths = @(
    $cargoBin,
    $mingwBin,
    (Join-Path $packageRoot 'cargo\bin'),
    (Join-Path $packageRoot 'toolchain\mingw64\bin')
)
if (-not [string]::IsNullOrWhiteSpace($oldMarker)) {
    $removePaths += (Join-Path $oldMarker 'cargo\bin')
    $removePaths += (Join-Path $oldMarker 'toolchain\mingw64\bin')
    $removePaths += (Join-Path $oldMarker 'windows\cargo\bin')
    $removePaths += (Join-Path $oldMarker 'windows\toolchain\mingw64\bin')
}
foreach ($oldHome in @($oldCargoHome, $oldMingwHome)) {
    if ([string]::IsNullOrWhiteSpace($oldHome)) { continue }
    $belongsToUs = Test-PathInside -Value $oldHome -Base $packageRoot
    if (-not $belongsToUs -and $oldMarker) {
        $belongsToUs = Test-PathInside -Value $oldHome -Base $oldMarker
    }
    if ($belongsToUs) {
        $removePaths += (Join-Path $oldHome 'bin')
    }
}

$currentEntries = @(Get-UserPathEntries)
$cleanedEntries = @(Remove-PathEntries -Entries $currentEntries -RemovePaths $removePaths)

if ($Remove) {
    Set-UserPathEntries -Entries $cleanedEntries

    $removedVariables = @()
    foreach ($name in @('CARGO_HOME', 'RUSTUP_HOME', 'MINGW_HOME', 'RUST_PORTABLE_HOME', 'RUST_PORTABLE_WINDOWS_DIR')) {
        $value = Get-UserValue -Name $name
        if ([string]::IsNullOrWhiteSpace($value)) { continue }

        $belongsToUs = Test-PathInside -Value $value -Base $packageRoot
        if (-not $belongsToUs -and $oldMarker) {
            $belongsToUs = Test-PathInside -Value $value -Base $oldMarker
        }
        if ($belongsToUs) {
            [Environment]::SetEnvironmentVariable($name, $null, 'User')
            $removedVariables += $name
        }
    }

    Send-EnvironmentChange
    Write-Host ''
    Write-Host '[rust-portable] Windows user environment cleaned.'
    if ($removedVariables.Count -gt 0) {
        Write-Host ('  Removed variables: ' + ($removedVariables -join ', '))
    }
    else {
        Write-Host '  No rust-portable variables were set for this package.'
    }
    Write-Host '  PATH entries for this package were removed.'
    Write-Host '  Open a NEW terminal for the change to take effect.'
    exit 0
}

$finalEntries = New-Object System.Collections.Generic.List[string]
$seen = @{}
foreach ($entry in @(@($cargoBin, $mingwBin) + $cleanedEntries)) {
    $normalized = Get-NormalizedEntry -Entry $entry
    if ($null -eq $normalized) { continue }

    $key = $normalized.ToLowerInvariant()
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = $true
    $finalEntries.Add($normalized)
}

Set-UserValue -Name 'CARGO_HOME' -Value $cargoHome
Set-UserValue -Name 'RUSTUP_HOME' -Value $rustupHome
Set-UserValue -Name 'MINGW_HOME' -Value $mingwHome
Set-UserValue -Name 'RUST_PORTABLE_HOME' -Value $packageRoot
Set-UserPathEntries -Entries $finalEntries.ToArray()
Send-EnvironmentChange

Write-Host ''
Write-Host '[rust-portable] Windows user environment configured (no administrator rights required).'
Write-Host "  RUST_PORTABLE_HOME = $packageRoot"
Write-Host "  CARGO_HOME         = $cargoHome"
Write-Host "  RUSTUP_HOME        = $rustupHome"
Write-Host "  MINGW_HOME         = $mingwHome"
Write-Host "  RUST_PORTABLE_SHARED = $sharedDir"
Write-Host '  PATH               = windows\cargo\bin and windows\toolchain\mingw64\bin were added first.'
if ($oldMarker -and -not (Test-SamePath -A $oldMarker -B $packageRoot)) {
    Write-Host "  Previous portable location removed from PATH: $oldMarker"
}
Write-Host ''
Write-Host '  Close and reopen terminals, VS Code, and other IDEs to use the new values.'
exit 0
