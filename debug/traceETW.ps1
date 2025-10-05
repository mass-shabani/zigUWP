# ==============================================================
# ETW Session برای نظارت بر برنامه‌های UWP/AppContainer
# نیاز به اجرا با Administrator privileges
# ==============================================================

# رنگ‌ها برای خروجی
$Host.UI.RawUI.ForegroundColor = "Green"

Write-Host "=== UWP/AppContainer ETW Monitor ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[✗] This script requires Administrator privileges to create ETW traces." -ForegroundColor Red
    Write-Host "   Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

# ۱. ایجاد ETW Trace Session برای AppModel
Write-Host "[1] Creating ETW Trace Session..." -ForegroundColor Yellow

$traceName = "UWPAppTrace"
$outputPath = "$env:TEMP\uwp_trace.etl"

# حذف session قبلی اگر وجود دارد
logman stop $traceName -ets 2>$null

# Providers مهم برای UWP:
$providers = @(
    # AppModel Runtime
    @{
        Name = "Microsoft-Windows-AppModel-Runtime"
        GUID = "{F1EF270A-0D32-4352-BA52-DBAB41E1D859}"
        Keywords = "0xFFFFFFFF"
        Level = "4"
    },
    # AppModel State
    @{
        Name = "Microsoft-Windows-AppModel-State"
        GUID = "{BFF15E13-81BF-45EE-8B16-7CFEAD00DA86}"
        Keywords = "0xFFFFFFFF"
        Level = "4"
    },
    # AppXDeployment
    @{
        Name = "Microsoft-Windows-AppXDeployment"
        GUID = "{8127F6D4-59F9-4ABF-8952-3E3A02073D5F}"
        Keywords = "0xFFFFFFFF"
        Level = "4"
    },
    # Process Lifecycle Manager
    @{
        Name = "Microsoft-Windows-ProcessLifetimeManager"
        GUID = "{072665FB-8953-5A85-931D-D06AEAB3D109}"
        Keywords = "0xFFFFFFFF"
        Level = "4"
    },
    # Kernel Process Provider
    @{
        Name = "Microsoft-Windows-Kernel-Process"
        GUID = "{22FB2CD6-0E7B-422B-A0C7-2FAD1FD0E716}"
        Keywords = "0x10"  # WINEVENT_KEYWORD_PROCESS
        Level = "4"
    }
)

# ساخت فایل providers
$providerFile = "$env:TEMP\uwp_providers.txt"
$providerContent = ""
foreach ($provider in $providers) {
    $providerContent += "$($provider.GUID)`t$($provider.Keywords)`t$($provider.Level)`n"
}
$providerContent | Out-File -FilePath $providerFile -Encoding ASCII

# ساخت دستور logman با فایل providers
$cmd = "logman create trace $traceName -ow -o `"$outputPath`" -nb 64 64 -bs 1024 -mode Circular -f bincirc -max 512 -pf `"$providerFile`" -ets"

Write-Host "Command: $cmd" -ForegroundColor DarkGray
Invoke-Expression $cmd

if ($LASTEXITCODE -eq 0) {
    Write-Host "[✓] ETW Session started successfully" -ForegroundColor Green
} else {
    Write-Host "[✗] Failed to start ETW Session" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[2] Monitoring is active. Launch your UWP app now..." -ForegroundColor Yellow
Write-Host "[3] Press any key to stop monitoring..." -ForegroundColor Yellow
Write-Host ""

# منتظر کلید کاربر
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# توقف trace
Write-Host ""
Write-Host "[4] Stopping ETW Session..." -ForegroundColor Yellow
logman stop $traceName -ets

if ($LASTEXITCODE -eq 0) {
    Write-Host "[✓] ETW Session stopped" -ForegroundColor Green
} else {
    Write-Host "[✗] Failed to stop ETW Session" -ForegroundColor Red
}

Write-Host ""
Write-Host "[5] Trace file saved to: $outputPath" -ForegroundColor Cyan
Write-Host ""

# تبدیل به فرمت قابل خواندن
Write-Host "[6] Converting trace to readable format..." -ForegroundColor Yellow

$xmlOutput = "$env:TEMP\uwp_trace.xml"
$txtOutput = "$env:TEMP\uwp_trace.txt"

# استفاده از tracerpt برای تبدیل
tracerpt "$outputPath" -o "$txtOutput" -of CSV -summary "$xmlOutput" 2>$null

if (Test-Path $txtOutput) {
    Write-Host "[✓] Converted to: $txtOutput" -ForegroundColor Green
    Write-Host ""
    
    # نمایش تعدادی از رویدادها
    Write-Host "=== Sample Events ===" -ForegroundColor Cyan
    Get-Content $txtOutput -Head 50 | Out-String | Write-Host
    
    Write-Host ""
    Write-Host "Full trace available at: $txtOutput" -ForegroundColor Cyan
    
    # باز کردن فایل
    $response = Read-Host "Open trace file? (Y/N)"
    if ($response -eq "Y" -or $response -eq "y") {
        notepad $txtOutput
    }
} else {
    Write-Host "[i] Use Windows Performance Analyzer to view: $outputPath" -ForegroundColor Yellow
    Write-Host "    Download from: https://docs.microsoft.com/en-us/windows-hardware/test/wpt/" -ForegroundColor DarkGray
}

# پاکسازی فایل providers
Remove-Item $providerFile -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== Monitoring Complete ===" -ForegroundColor Cyan