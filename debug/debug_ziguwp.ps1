# debug_ziguwp.ps1
# اسکریپت جامع برای Debug کردن ZigUWP

param(
    [switch]$Build,
    [switch]$Deploy,
    [switch]$Run,
    [switch]$ShowLogs,
    [switch]$Clean,
    [switch]$All,
    [switch]$PackageStatus
)

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "ZigUWP Debug Helper" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# رنگ‌ها
function Write-Success { param($msg) Write-Host "[✓] $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "[i] $msg" -ForegroundColor Cyan }
function Write-Warning { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "[✗] $msg" -ForegroundColor Red }

# متغیرها
$PackageName = "ZigUWP.ModularApp"
$LogFile = "$env:LOCALAPPDATA\ziguwp_debug.log"

# تابع برای پاک کردن
function Clean-Build {
    Write-Info "Cleaning build artifacts..."
    
    if (Test-Path "zig-out") {
        Remove-Item -Path "zig-out" -Recurse -Force
        Write-Success "Cleaned zig-out directory"
    }
    
    if (Test-Path "zig-cache") {
        Remove-Item -Path "zig-cache" -Recurse -Force
        Write-Success "Cleaned zig-cache directory"
    }
    
    if (Test-Path $LogFile) {
        Remove-Item -Path $LogFile -Force
        Write-Success "Cleaned old log file"
    }
}

# تابع برای Build
function Build-Project {
    Write-Info "Building ZigUWP project..."
    
    try {
        zig build
        Write-Success "Build completed successfully"
        return $true
    } catch {
        Write-Error "Build failed: $_"
        return $false
    }
}

# تابع برای Deploy
function Deploy-Package {
    Write-Info "Deploying UWP package..."
    
    # پیدا کردن package
    $pkg = Get-AppxPackage -Name "*$PackageName*"
    
    if ($pkg) {
        Write-Warning "Package already installed. Removing..."
        Remove-AppxPackage -Package $pkg.PackageFullName
        Start-Sleep -Seconds 2
    }
    
    # پیدا کردن AppX Manifest
    $manifestPath = ".\AppxManifest.xml"
    
    if (-not (Test-Path $manifestPath)) {
        Write-Error "AppxManifest.xml not found in current directory"
        return $false
    }
    
    try {
        Add-AppxPackage -Register $manifestPath -ForceUpdateFromAnyVersion
        Write-Success "Package deployed successfully"
        return $true
    } catch {
        Write-Error "Deployment failed: $_"
        return $false
    }
}

# تابع برای اجرا
function Run-Application {
    Write-Info "Running ZigUWP application..."
    
    $pkg = Get-AppxPackage -Name "*$PackageName*"
    
    if (-not $pkg) {
        Write-Error "Package not found. Deploy first!"
        return $false
    }
    
    $aumid = "$($pkg.PackageFamilyName)!App"
    Write-Info "AUMID: $aumid"
    
    try {
        Start-Process "explorer.exe" -ArgumentList "shell:AppsFolder\$aumid"
        Write-Success "Application launched"
        
        # صبر کنید تا process شروع شود
        Start-Sleep -Seconds 2
        
        # پیدا کردن process
        $process = Get-Process | Where-Object {
            $_.Path -like "*WindowsApps*$PackageName*"
        }
        
        if ($process) {
            Write-Success "Process found: PID = $($process.Id)"
            Write-Info "Monitor this PID in DebugView"
        } else {
            Write-Warning "Process not found yet. May have crashed?"
        }
        
        return $true
    } catch {
        Write-Error "Failed to launch: $_"
        return $false
    }
}

# تابع برای نمایش لاگ‌ها
function Show-Logs {
    Write-Info "Checking log files..."
    
    # فایل لاگ
    if (Test-Path $LogFile) {
        Write-Success "Log file found: $LogFile"
        Write-Host "`n--- Last 50 lines of log ---`n" -ForegroundColor Yellow
        Get-Content $LogFile -Tail 50 | Write-Host
        Write-Host "`n--- End of log ---`n" -ForegroundColor Yellow
        
        # پیشنهاد باز کردن
        $response = Read-Host "Open full log file? (Y/N)"
        if ($response -eq "Y" -or $response -eq "y") {
            Start-Process notepad.exe -ArgumentList $LogFile
        }
    } else {
        Write-Warning "Log file not found at: $LogFile"
        Write-Info "The application may not have run yet."
    }
    
    # Event Viewer
    Write-Host "`n"
    Write-Info "Checking Event Viewer for errors..."
    
    $events = Get-WinEvent -FilterHashtable @{
        LogName = 'Microsoft-Windows-TWinUI/Operational'
        Level = 2
        StartTime = (Get-Date).AddMinutes(-10)
    } -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -like "*$PackageName*" } |
    Select-Object -First 5
    
    if ($events) {
        Write-Warning "Found recent errors in Event Viewer:"
        foreach ($event in $events) {
            Write-Host "`nTime: $($event.TimeCreated)" -ForegroundColor Gray
            Write-Host "Message: $($event.Message)" -ForegroundColor Gray
        }
    } else {
        Write-Success "No recent errors in Event Viewer"
    }
}

# تابع برای نمایش وضعیت Package
function Show-PackageStatus {
    Write-Info "Checking package status..."
    
    $pkg = Get-AppxPackage -Name "*$PackageName*"
    
    if ($pkg) {
        Write-Success "Package installed:"
        Write-Host "  Name: $($pkg.Name)" -ForegroundColor Gray
        Write-Host "  Version: $($pkg.Version)" -ForegroundColor Gray
        Write-Host "  Status: $($pkg.Status)" -ForegroundColor Gray
        Write-Host "  Location: $($pkg.InstallLocation)" -ForegroundColor Gray
        Write-Host "  Family: $($pkg.PackageFamilyName)" -ForegroundColor Gray
        
        # بررسی فایل executable
        $exePath = Join-Path $pkg.InstallLocation "zigUWP.exe"
        if (Test-Path $exePath) {
            Write-Success "Executable found: zigUWP.exe"
            $fileInfo = Get-Item $exePath
            Write-Host "  Size: $($fileInfo.Length) bytes" -ForegroundColor Gray
            Write-Host "  Modified: $($fileInfo.LastWriteTime)" -ForegroundColor Gray
        } else {
            Write-Error "Executable not found!"
        }
    } else {
        Write-Warning "Package not installed"
    }
}

# تابع برای نمایش Process های در حال اجرا
function Show-RunningProcesses {
    Write-Info "Checking for running ZigUWP processes..."
    
    $processes = Get-Process | Where-Object {
        $_.ProcessName -like "*zig*" -or 
        $_.Path -like "*$PackageName*"
    }
    
    if ($processes) {
        Write-Success "Found process(es):"
        $processes | Format-Table Id, ProcessName, @{
            Label="Memory (MB)"; 
            Expression={[math]::Round($_.WorkingSet64 / 1MB, 2)}
        }, Path -AutoSize
    } else {
        Write-Info "No ZigUWP processes running"
    }
}

# منوی اصلی
function Show-Menu {
    Write-Host "`nAvailable actions:" -ForegroundColor Cyan
    Write-Host "  1. Clean build artifacts"
    Write-Host "  2. Build project"
    Write-Host "  3. Deploy package"
    Write-Host "  4. Run application"
    Write-Host "  5. Show logs"
    Write-Host "  6. Show package status"
    Write-Host "  7. Show running processes"
    Write-Host "  8. Full workflow (Clean + Build + Deploy + Run)"
    Write-Host "  0. Exit"
    Write-Host ""
    
    $choice = Read-Host "Choose action"
    
    switch ($choice) {
        "1" { Clean-Build }
        "2" { Build-Project }
        "3" { Deploy-Package }
        "4" { Run-Application }
        "5" { Show-Logs }
        "6" { Show-PackageStatus }
        "7" { Show-RunningProcesses }
        "8" {
            Clean-Build
            if (Build-Project) {
                if (Deploy-Package) {
                    Start-Sleep -Seconds 2
                    Run-Application
                    Start-Sleep -Seconds 3
                    Show-Logs
                }
            }
        }
        "0" { exit }
        default { Write-Warning "Invalid choice" }
    }
    
    Write-Host "`n"
    Show-Menu
}

# اجرا بر اساس پارامترها
if ($Clean) { Clean-Build }
if ($Build) { Build-Project }
if ($Deploy) { Deploy-Package }
if ($Run) { Run-Application }
if ($ShowLogs) { Show-Logs }

if ($All) {
    Clean-Build
    if (Build-Project) {
        if (Deploy-Package) {
            Start-Sleep -Seconds 2
            Run-Application
            Start-Sleep -Seconds 3
            Show-Logs
        }
    }
    exit
}
if ($PackageStatus) { Show-PackageStatus }

# اگر هیچ پارامتری داده نشد، منو را نشان بده
if (-not ($Clean -or $Build -or $Deploy -or $Run -or $ShowLogs -or $All)) {
    Show-Menu
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Done!" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan