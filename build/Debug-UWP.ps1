#Requires -Version 5.1

<#
.SYNOPSIS
    بررسی صحت تنظیمات UWP قبل از build

.DESCRIPTION
    این اسکریپت موارد زیر را چک می‌کند:
    - main.zig دارای wWinMainCRTStartup است
    - build.zig دارای exe.subsystem = .Windows است
    - AppxManifest.xml دارای EntryPoint معتبر است
    - فایل‌های Asset موجود هستند
#>

Write-Host "`n=== UWP Setup Verification ===" -ForegroundColor Cyan
Write-Host "Checking your project configuration...`n"

$errors = @()
$warnings = @()
$passed = 0

# =====================================================================
# بررسی main.zig
# =====================================================================

Write-Host "[1] Checking main.zig..." -ForegroundColor Yellow

$mainZigPath = "..\src\main.zig"

if (-not (Test-Path $mainZigPath)) {
    $errors += "main.zig not found at: $mainZigPath"
} else {
    $mainContent = Get-Content $mainZigPath -Raw
    
    # بررسی wWinMainCRTStartup
    if ($mainContent -match 'pub\s+export\s+fn\s+wWinMainCRTStartup') {
        Write-Host "  ✓ wWinMainCRTStartup found" -ForegroundColor Green
        $passed++
    } else {
        $errors += "main.zig does not export wWinMainCRTStartup"
        Write-Host "  ✗ wWinMainCRTStartup NOT found" -ForegroundColor Red
    }
    
    # بررسی wWinMain
    if ($mainContent -match 'pub\s+fn\s+wWinMain') {
        Write-Host "  ✓ wWinMain function found" -ForegroundColor Green
        $passed++
    } else {
        $errors += "main.zig does not have wWinMain function"
        Write-Host "  ✗ wWinMain function NOT found" -ForegroundColor Red
    }
    
    # بررسی OutputDebugStringW
    if ($mainContent -match 'OutputDebugStringW') {
        Write-Host "  ✓ Debug logging enabled" -ForegroundColor Green
        $passed++
    } else {
        $warnings += "No OutputDebugStringW - debugging will be harder"
        Write-Host "  ⚠ Debug logging not detected" -ForegroundColor Yellow
    }
    
    # بررسی main() که نباید استفاده شود
    if ($mainContent -match 'pub\s+fn\s+main\(\s*\)\s+') {
        if ($mainContent -match 'UWPAppCannotRunDirectly') {
            Write-Host "  ✓ main() has proper warning message" -ForegroundColor Green
            $passed++
        } else {
            $warnings += "main() exists but should show UWP warning"
            Write-Host "  ⚠ main() should show UWP-specific warning" -ForegroundColor Yellow
        }
    }
}

Write-Host ""

# =====================================================================
# بررسی build.zig
# =====================================================================

Write-Host "[2] Checking build.zig..." -ForegroundColor Yellow

$buildZigPath = "build.zig"

if (-not (Test-Path $buildZigPath)) {
    $errors += "build.zig not found"
} else {
    $buildContent = Get-Content $buildZigPath -Raw
    
    # بررسی subsystem
    if ($buildContent -match 'exe\.subsystem\s*=\s*\.Windows') {
        Write-Host "  ✓ exe.subsystem = .Windows is set" -ForegroundColor Green
        $passed++
    } else {
        $errors += "build.zig missing: exe.subsystem = .Windows"
        Write-Host "  ✗ exe.subsystem = .Windows NOT found" -ForegroundColor Red
        Write-Host "    Add this line after exe = b.addExecutable(...):" -ForegroundColor Yellow
        Write-Host "    exe.subsystem = .Windows;" -ForegroundColor Yellow
    }
    
    # بررسی لینک کتابخانه‌ها
    $requiredLibs = @('ole32', 'WindowsApp', 'runtimeobject', 'combase')
    foreach ($lib in $requiredLibs) {
        if ($buildContent -match "exe\.linkSystemLibrary\(`"$lib`"") {
            Write-Host "  ✓ Links $lib" -ForegroundColor Green
            $passed++
        } else {
            $warnings += "build.zig may be missing: exe.linkSystemLibrary(`"$lib`")"
            Write-Host "  ⚠ $lib not explicitly linked" -ForegroundColor Yellow
        }
    }
}

Write-Host ""

# =====================================================================
# بررسی AppxManifest.xml
# =====================================================================

Write-Host "[3] Checking AppxManifest.xml..." -ForegroundColor Yellow

$manifestPath = "AppxManifest.xml"

if (-not (Test-Path $manifestPath)) {
    $errors += "AppxManifest.xml not found"
} else {
    try {
        [xml]$manifest = Get-Content $manifestPath
        
        $identity = $manifest.Package.Identity
        $app = $manifest.Package.Applications.Application
        
        # بررسی Publisher
        if ($identity.Publisher) {
            Write-Host "  ✓ Publisher: $($identity.Publisher)" -ForegroundColor Green
            $passed++
        } else {
            $errors += "Manifest missing Publisher"
        }
        
        # بررسی EntryPoint
        if ($app.EntryPoint) {
            Write-Host "  ✓ EntryPoint: $($app.EntryPoint)" -ForegroundColor Green
            
            # بررسی EntryPoint اشتباه
            if ($app.EntryPoint -eq "Windows.ApplicationModel.Core.CoreApplication") {
                $errors += "EntryPoint is set to Windows.ApplicationModel.Core.CoreApplication (only for .NET apps!)"
                Write-Host "    ✗ This EntryPoint is for .NET apps only!" -ForegroundColor Red
                Write-Host "    Change to: YourPackageName.App" -ForegroundColor Yellow
            } else {
                $passed++
            }
        } else {
            $errors += "Manifest missing EntryPoint - MakeAppx will fail"
            Write-Host "  ✗ EntryPoint is missing" -ForegroundColor Red
        }
        
        # بررسی Executable
        if ($app.Executable) {
            Write-Host "  ✓ Executable: $($app.Executable)" -ForegroundColor Green
            
            if ($app.Executable -ne "zigUWP.exe") {
                $warnings += "Executable name doesn't match expected zigUWP.exe"
            } else {
                $passed++
            }
        } else {
            $errors += "Manifest missing Executable"
        }
        
        # بررسی Assets
        $requiredAssets = @(
            @{ Path = $manifest.Package.Properties.Logo; Name = "StoreLogo" },
            @{ Path = $app.'uap:VisualElements'.Square150x150Logo; Name = "Square150x150Logo" },
            @{ Path = $app.'uap:VisualElements'.Square44x44Logo; Name = "Square44x44Logo" },
            @{ Path = $app.'uap:VisualElements'.'uap:DefaultTile'.Wide310x150Logo; Name = "Wide310x150Logo" },
            @{ Path = $app.'uap:VisualElements'.'uap:SplashScreen'.Image; Name = "SplashScreen" }
        )

        Write-Host "`n  Checking Assets:" -ForegroundColor Cyan
        foreach ($asset in $requiredAssets) {
            if ($asset.Path) {
                $assetPath = ".." + $asset.Path
                if (Test-Path $assetPath) {
                    Write-Host "    ✓ $($asset.Name): $assetPath" -ForegroundColor Green
                    $passed++
                } else {
                    $warnings += "Asset file missing: $assetPath"
                    Write-Host "    ✗ $($asset.Name): $assetPath (NOT FOUND)" -ForegroundColor Red
                }
            }
        }
        
    } catch {
        $errors += "Failed to parse AppxManifest.xml: $_"
    }
}

Write-Host ""

# =====================================================================
# بررسی ساختار پروژه
# =====================================================================

Write-Host "[4] Checking project structure..." -ForegroundColor Yellow

$requiredDirs = @('..\src', '..\src\core', '..\src\interfaces', '..\src\implementation', '..\src\utils', '..\assets\images', '..\Libs')

foreach ($dir in $requiredDirs) {
    if (Test-Path $dir) {
        Write-Host "  ✓ $dir exists" -ForegroundColor Green
        $passed++
    } else {
        $warnings += "Directory missing: $dir"
        Write-Host "  ⚠ $dir missing" -ForegroundColor Yellow
    }
}

Write-Host ""

# =====================================================================
# بررسی Build Output
# =====================================================================

Write-Host "[5] Checking previous build output..." -ForegroundColor Yellow

if (Test-Path "zig-out\bin\zigUWP.exe") {
    Write-Host "  ✓ Previous build found" -ForegroundColor Green
    
    # بررسی subsystem با dumpbin (اگر موجود باشد)
    $dumpbin = Get-Command dumpbin -ErrorAction SilentlyContinue
    if ($dumpbin) {
        $subsystemInfo = & dumpbin /headers "zig-out\bin\zigUWP.exe" 2>$null | Select-String "subsystem"
        
        if ($subsystemInfo -match "Windows GUI") {
            Write-Host "    ✓ Subsystem: Windows GUI (Correct!)" -ForegroundColor Green
            $passed++
        } elseif ($subsystemInfo -match "Windows CUI") {
            $errors += "Executable built with Console subsystem - needs Windows subsystem"
            Write-Host "    ✗ Subsystem: Windows CUI (Wrong! Should be GUI)" -ForegroundColor Red
        } else {
            Write-Host "    ? Subsystem: $subsystemInfo" -ForegroundColor Yellow
        }
    } else {
        Write-Host "    ⚠ dumpbin not found - cannot verify subsystem" -ForegroundColor Yellow
        Write-Host "      (Install Visual Studio Build Tools for dumpbin)" -ForegroundColor Gray
    }
} else {
    Write-Host "  ⚠ No previous build found - run: zig build" -ForegroundColor Yellow
}

Write-Host ""

# =====================================================================
# نتیجه نهایی
# =====================================================================

Write-Host "=== Summary ===" -ForegroundColor Cyan

Write-Host "`nPassed checks: $passed" -ForegroundColor Green

if ($warnings.Count -gt 0) {
    Write-Host "`nWarnings ($($warnings.Count)):" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "  ⚠ $warning" -ForegroundColor Yellow
    }
}

if ($errors.Count -gt 0) {
    Write-Host "`nErrors ($($errors.Count)):" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "  ✗ $err" -ForegroundColor Red
    }
    Write-Host "`n❌ Configuration has errors - please fix them before building!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✓ Configuration looks good!" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "  1. Clean previous builds: zig build clean"
    Write-Host "  2. Rebuild: zig build"
    Write-Host "  3. Package and install: zig build all-appx"
    Write-Host "  4. Download DebugView from Microsoft Sysinternals"
    Write-Host "  5. Run DebugView as Administrator"
    Write-Host "  6. Enable: Capture > Capture Global Win32"
    Write-Host "  7. Launch zigUWP from Start Menu"
    Write-Host "  8. Watch debug output in DebugView"
    exit 0
}