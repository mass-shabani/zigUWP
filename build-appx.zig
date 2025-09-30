const std = @import("std");

// متغیرهای پیکربندی
const DEFAULT_WINDOWS_SDK_PATH = "C:\\Program Files (x86)\\Windows Kits\\10\\bin\\10.0.26100.0\\x64";
const TIMESTAMP_SERVER_URL = "http://timestamp.digicert.com";

// تنظیمات ناشر و سرتیفیکیت
const PUBLISHER_NAME = "CN=Massoud, O=Massoud, C=IR";
const CERT_PASSWORD = "zigUWP123!";
const CERT_SUBJECT = "zigUWP Self-Signed Certificate";
const CERT_FILE_PATH = "zig-out/bin/zigUWP.pfx";

// مسیرها و فایل‌های استاتیک
const BIN_DIR = "zig-out/bin";
const PACKAGE_DIR_NAME = "package";
const PACKAGE_DIR = BIN_DIR ++ "/" ++ PACKAGE_DIR_NAME;
const PACKAGE_MANIFEST_PATH = "assets/appx/AppxManifest.xml";
const PACKAGE_ASSETS_PATH = "assets/images/*";
const PACKAGE_ASSETS_DEST = PACKAGE_DIR ++ "/assets/";
const LIBS_SOURCE_PATH = "Libs/*";
const LIBS_DEST_PATH = BIN_DIR ++ "/package/Libs/";
const PACKAGE_OUTPUT_PATH = BIN_DIR ++ "/zigUWP.appx";
const MAKEAPPX_EXE = "MakeAppx.exe";
const SIGNTOOL_EXE = "SignTool.exe";
const SIGNTOOL_STORE = "My";

// تابع برای تولید خودکار سرتیفیکیت
fn createSelfSignedCertificate(b: *std.Build) *std.Build.Step {
    const create_cert_step = b.step("create-cert", "Create self-signed certificate");

    const create_cert = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt("$certPath = '{s}'; $certSubject = '{s}'; $certPassword = '{s}'; if (-not (Test-Path $certPath)) {{ Write-Host 'Creating self-signed certificate...'; $cert = New-SelfSignedCertificate -Subject $certSubject -CertStoreLocation Cert:\\LocalMachine\\My -KeySpec KeyExchange -KeyUsage DigitalSignature -NotAfter (Get-Date).AddYears(1); $securePassword = ConvertTo-SecureString $certPassword -AsPlainText -Force; Export-PfxCertificate -Cert $cert -FilePath $certPath -Password $securePassword; Write-Host 'Certificate created successfully at:' $certPath }} else {{ Write-Host 'Certificate already exists at:' $certPath }}", .{ CERT_FILE_PATH, CERT_SUBJECT, CERT_PASSWORD }),
    });

    create_cert_step.dependOn(&create_cert.step);
    return create_cert_step;
}

// تابع برای آپدیت کردن فایل AppxManifest.xml با نام ناشر
fn updateManifestWithPublisher(b: *std.Build) *std.Build.Step.Run {
    // const update_manifest_step = b.step("update-manifest", "Update AppxManifest.xml with publisher name");

    const update_manifest = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt("$manifestPath = '{s}'; $publisher = '{s}'; if (Test-Path $manifestPath) {{ Write-Host 'Updating manifest with publisher:' $publisher; $content = Get-Content $manifestPath -Raw; $content = $content -replace '<Publisher>.*?</Publisher>', '<Publisher>' + $publisher + '</Publisher>'; $content | Out-File -FilePath $manifestPath -Encoding UTF8; Write-Host 'Manifest updated successfully' }} else {{ Write-Host 'Manifest file not found:' $manifestPath }}", .{ PACKAGE_MANIFEST_PATH, PUBLISHER_NAME }),
    });

    // update_manifest_step.dependOn(&update_manifest.step);
    return update_manifest;
}

pub fn createPackageStep(b: *std.Build) *std.Build.Step {
    const package_step = b.step("package", "Create UWP package");

    // مسیرهای مورد نیاز
    const bin_dir = "zig-out/bin";
    const package_dir = b.pathJoin(&.{ bin_dir, "package" });

    // تعریف تمام مراحل
    const create_package_dir = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt("New-Item -Path '{s}' -ItemType Directory -Force | Out-Null", .{package_dir}),
    });

    const copy_exe = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt("Copy-Item -Path '{s}/zigUWP.exe' -Destination '{s}/' -Force", .{ BIN_DIR, PACKAGE_DIR }),
    });

    const copy_manifest = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt("Copy-Item -Path '{s}' -Destination '{s}/' -Force", .{ PACKAGE_MANIFEST_PATH, PACKAGE_DIR }),
    });

    const create_assets_dir = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt("New-Item -Path '{s}/assets' -ItemType Directory -Force | Out-Null", .{PACKAGE_DIR}),
    });

    const copy_assets = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt("Copy-Item -Path '{s}' -Destination '{s}' -Recurse -Force", .{ PACKAGE_ASSETS_PATH, PACKAGE_ASSETS_DEST }),
    });

    const create_libs_dir = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt("New-Item -Path '{s}/Libs' -ItemType Directory -Force | Out-Null", .{PACKAGE_DIR}),
    });

    const copy_libs = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt("if (Test-Path '{s}') {{ Copy-Item -Path '{s}' -Destination '{s}' -Recurse -Force }}", .{ LIBS_SOURCE_PATH, LIBS_SOURCE_PATH, LIBS_DEST_PATH }),
    });

    const make_appx = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt("$makeAppxPath = $env:MAKEAPPX_PATH; if (-not $makeAppxPath) {{ $makeAppxPath = '{s}' }}; $env:PATH += ';' + $makeAppxPath; if (Get-Command 'MakeAppx' -ErrorAction SilentlyContinue) {{ MakeAppx pack /d '{s}' /p '{s}' /l }} else {{ if (Test-Path ($makeAppxPath + '\\\\{s}')) {{ & ($makeAppxPath + '\\\\{s}') pack /d '{s}' /p '{s}' /l }} else {{ Write-Host 'MakeAppx tool not found, skipping package creation' }} }}", .{ DEFAULT_WINDOWS_SDK_PATH, PACKAGE_DIR, PACKAGE_OUTPUT_PATH, MAKEAPPX_EXE, MAKEAPPX_EXE, PACKAGE_DIR, PACKAGE_OUTPUT_PATH }),
    });

    const sign_appx = b.addSystemCommand(&.{
        "PowerShell",
        "-File",
        "sign-appx.ps1",
        "-PublisherName",
        PUBLISHER_NAME,
        "-CertPassword",
        CERT_PASSWORD,
        "-CertSubject",
        CERT_SUBJECT,
        "-CertFilePath",
        CERT_FILE_PATH,
    });

    const install_appx = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt("$skipSigning = [Environment]::GetEnvironmentVariable('SKIP_SIGNING') -eq 'true'; if ($skipSigning) {{ Write-Host 'Development mode: Installing unsigned package' }}; if (Test-Path '{s}') {{ try {{ Add-AppxPackage -Path '{s}' -ForceUpdateFromAnyVersion }} catch {{ if ($skipSigning) {{ Write-Host 'Failed to install unsigned package, trying development deployment method...'; Start-Process 'powershell' -ArgumentList '-Command', 'Add-AppxPackage -Path \"{s}\" -ForceUpdateFromAnyVersion -DevelopmentMode' -Wait }} else {{ throw }} }} }} else {{ Write-Host 'Package file not found, skipping installation' }}", .{ PACKAGE_OUTPUT_PATH, PACKAGE_OUTPUT_PATH, PACKAGE_OUTPUT_PATH }),
    });

    // اضافه کردن مرحله آپدیت کردن مانیفست با نام ناشر
    const update_manifest = updateManifestWithPublisher(b);

    copy_exe.step.dependOn(&create_package_dir.step);
    copy_manifest.step.dependOn(&copy_exe.step);
    update_manifest.step.dependOn(&copy_manifest.step);
    create_assets_dir.step.dependOn(&update_manifest.step);
    copy_assets.step.dependOn(&create_assets_dir.step);
    create_libs_dir.step.dependOn(&copy_assets.step);
    copy_libs.step.dependOn(&create_libs_dir.step);
    make_appx.step.dependOn(&copy_libs.step);
    sign_appx.step.dependOn(&make_appx.step);
    install_appx.step.dependOn(&sign_appx.step);
    package_step.dependOn(&install_appx.step);

    // تعریف مراحل جداگانه
    const create_cert_step = createSelfSignedCertificate(b);
    const sign_step = b.step("sign-appx", "Sign UWP package");
    sign_step.dependOn(&make_appx.step);
    sign_step.dependOn(&sign_appx.step);
    sign_step.dependOn(create_cert_step);

    const install_step = b.step("install-appx", "Install UWP package");
    install_step.dependOn(&sign_appx.step);
    install_step.dependOn(&install_appx.step);

    const all_step = b.step("all-appx", "Build, package, sign and install UWP application");
    all_step.dependOn(&install_appx.step);

    return package_step;
}

pub fn createCleanStep(b: *std.Build) *std.Build.Step {
    const clean_step = b.step("clean", "Clean build artifacts");
    const clean_cmd = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt("Remove-Item -Path '{s}' -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path 'zig-cache' -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item '*.appx' -Force -ErrorAction SilentlyContinue", .{BIN_DIR}),
    });
    clean_step.dependOn(&clean_cmd.step);
    return clean_step;
}
