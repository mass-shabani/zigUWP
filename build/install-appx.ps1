<#
.SYNOPSIS
    Installs the built UWP app package for development.

.DESCRIPTION
    Registers the UWP app package using Add-AppxPackage for testing during development.
    Usage: ./install-appx.ps1
#>

try {
    $manifestPath = "zig-out\bin\package\AppxManifest.xml"

    if (-not (Test-Path $manifestPath)) {
        throw "Manifest file not found: $manifestPath. Run 'zig build package' first."
    }

    Write-Host '[INFO] Registering package for development...'
    Add-AppxPackage -Register $manifestPath
    Write-Host '[OK] Package registered successfully'
} catch {
    Write-Error "Failed to register package: $_"
    Write-Host 'Tip: Ensure Developer Mode is enabled in Windows Settings > Update & Security > For developers'
    exit 1
}