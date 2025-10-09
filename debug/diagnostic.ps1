# debug\diagnostic.ps1

# اجرا با: PowerShell به عنوان Administrator
# سپس: .\diagnostic.ps1

$PackageName = "ZigUWP.ModularApp"

Write-Host "`n===================================" -ForegroundColor Cyan
Write-Host "UWP Crash Quick Diagnostic Tool" -ForegroundColor Cyan
Write-Host "===================================`n" -ForegroundColor Cyan

# 1. پیدا کردن Package
Write-Host "[Step 1/6] Searching for package..." -ForegroundColor Yellow
$pkg = Get-AppxPackage -Name "*$PackageName*"

if ($null -eq $pkg) {
    Write-Host "ERROR: Package not found!" -ForegroundColor Red
    Write-Host "Package '$PackageName' is not installed.`n" -ForegroundColor Red
    exit 1
}

Write-Host "FOUND: $($pkg.Name)" -ForegroundColor Green
Write-Host "  Version: $($pkg.Version)" -ForegroundColor Gray
Write-Host "  Location: $($pkg.InstallLocation)`n" -ForegroundColor Gray

# 2. بررسی فایل‌های اصلی
Write-Host "[Step 2/6] Checking critical files..." -ForegroundColor Yellow

$manifestPath = Join-Path $pkg.InstallLocation "AppXManifest.xml"
if (-not (Test-Path $manifestPath)) {
    Write-Host "ERROR: AppXManifest.xml missing!" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ AppXManifest.xml exists" -ForegroundColor Green

[xml]$manifest = Get-Content $manifestPath
$executable = $manifest.Package.Applications.Application.Executable
$exePath = Join-Path $pkg.InstallLocation $executable

if (-not (Test-Path $exePath)) {
    Write-Host "ERROR: Executable not found!" -ForegroundColor Red
    Write-Host "  Expected: $exePath" -ForegroundColor Red
    Write-Host "`nSOLUTION: Check your build output. EXE file is missing!`n" -ForegroundColor Yellow
    exit 1
}
Write-Host "  ✓ Executable exists: $executable`n" -ForegroundColor Green

# 3. بررسی Dependencies
Write-Host "[Step 3/6] Checking dependencies..." -ForegroundColor Yellow

$vcLibs = Get-AppxPackage -Name "*VCLibs*"
if ($null -eq $vcLibs) {
    Write-Host "WARNING: VCLibs not found!" -ForegroundColor Red
    Write-Host "SOLUTION: Install VCLibs framework" -ForegroundColor Yellow
    Write-Host "  Run: Add-AppxPackage 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'`n" -ForegroundColor Gray
} else {
    Write-Host "  ✓ VCLibs installed: v$($vcLibs.Version)`n" -ForegroundColor Green
}

# 4. چک Entry Point
Write-Host "[Step 4/6] Checking Entry Point..." -ForegroundColor Yellow
$entryPoint = $manifest.Package.Applications.Application.EntryPoint

if ($entryPoint -ne "Windows.FullTrustApplication") {
    Write-Host "WARNING: EntryPoint = '$entryPoint'" -ForegroundColor Yellow
    Write-Host "  For native EXE, it should be 'Windows.FullTrustApplication'" -ForegroundColor Yellow
} else {
    Write-Host "  ✓ EntryPoint is correct`n" -ForegroundColor Green
}

# 5. چک Capabilities
Write-Host "[Step 5/6] Checking Capabilities..." -ForegroundColor Yellow
$hasFullTrust = $manifest.Package.Capabilities.Capability | 
                Where-Object { $_.Name -eq "runFullTrust" }

if ($null -eq $hasFullTrust) {
    Write-Host "ERROR: Missing 'runFullTrust' capability!" -ForegroundColor Red
    Write-Host "SOLUTION: Add to AppXManifest.xml:" -ForegroundColor Yellow
    Write-Host "  <Capabilities>" -ForegroundColor Gray
    Write-Host "    <rescap:Capability Name=`"runFullTrust`" />" -ForegroundColor Gray
    Write-Host "  </Capabilities>`n" -ForegroundColor Gray
} else {
    Write-Host "  ✓ runFullTrust capability present`n" -ForegroundColor Green
}

# 6. چک Event Log
Write-Host "[Step 6/6] Checking recent errors in Event Log..." -ForegroundColor Yellow

$events = Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-TWinUI/Operational'
    Level = 2  # Error
    StartTime = (Get-Date).AddMinutes(-10)
} -ErrorAction SilentlyContinue | 
Where-Object { $_.Message -like "*$PackageName*" } |
Select-Object -First 3

if ($events) {
    Write-Host "`nRECENT ERRORS FOUND:" -ForegroundColor Red
    foreach ($event in $events) {
        Write-Host "  Time: $($event.TimeCreated)" -ForegroundColor Gray
        Write-Host "  Message: $($event.Message)`n" -ForegroundColor Gray
    }
} else {
    Write-Host "  No recent errors found`n" -ForegroundColor Green
}

# خلاصه و راه‌حل
Write-Host "`n===================================" -ForegroundColor Cyan
Write-Host "DIAGNOSIS COMPLETE" -ForegroundColor Cyan
Write-Host "===================================`n" -ForegroundColor Cyan

Write-Host "QUICK FIXES TO TRY:`n" -ForegroundColor Yellow

Write-Host "1. Re-register the package:" -ForegroundColor White
Write-Host "   Add-AppxPackage -Register `"$manifestPath`" -DisableDevelopmentMode`n" -ForegroundColor Gray

Write-Host "2. Check Event Viewer manually:" -ForegroundColor White
Write-Host "   eventvwr.msc → Windows Logs → Application`n" -ForegroundColor Gray

Write-Host "3. Try running EXE directly (testing):" -ForegroundColor White
Write-Host "   cd `"$($pkg.InstallLocation)`"" -ForegroundColor Gray
Write-Host "   .\$executable`n" -ForegroundColor Gray

Write-Host "4. Check dependencies with Dependency Walker:" -ForegroundColor White
Write-Host "   Download: https://dependencywalker.com/`n" -ForegroundColor Gray

$response = Read-Host "Do you want to try re-registering the package now? (Y/N)"
if ($response -eq "Y" -or $response -eq "y") {
    Write-Host "`nRe-registering package..." -ForegroundColor Yellow
    try {
        Add-AppxPackage -Register $manifestPath -DisableDevelopmentMode
        Write-Host "SUCCESS: Package re-registered!" -ForegroundColor Green
        Write-Host "Try launching the app again.`n" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to re-register: $($_.Exception.Message)`n" -ForegroundColor Red
    }
}
