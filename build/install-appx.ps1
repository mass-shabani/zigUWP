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