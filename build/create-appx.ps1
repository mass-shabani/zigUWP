<#
.SYNOPSIS
    Creates APPX package from prepared package directory.

.DESCRIPTION
    Uses MakeAppx.exe to create a .appx package from the package directory structure.
    Usage: ./create-appx.ps1 [-PackageDir path] [-OutputPath path]
#>

param(
    [string]$PackageDir = "zig-out/bin/package",
    [string]$OutputPath = "zig-out/bin/zigUWP.appx",
    [string]$SdkPath = ""
)

try {
    if (-not $SdkPath) {
        $SdkPath = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64"
    }

    $makeAppx = Join-Path $SdkPath 'MakeAppx.exe'

    if (-not (Test-Path $makeAppx)) {
        throw "MakeAppx.exe not found at: $makeAppx"
    }

    if (-not (Test-Path $PackageDir)) {
        throw "Package directory not found: $PackageDir"
    }

    Write-Host '[INFO] Creating APPX package...'
    & $makeAppx pack /d $PackageDir /p $OutputPath /l /o

    if ($LASTEXITCODE -ne 0) {
        throw "MakeAppx failed with exit code: $LASTEXITCODE"
    }

    Write-Host '[OK] Package created successfully' -ForegroundColor Green
     Write-Host ''
} catch {
    Write-Error "Failed to create package: $_"
    exit 1
}