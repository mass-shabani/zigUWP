const std = @import("std");
// build-appx.zig
// =====================================================================
// Configuration Constants
// =====================================================================

const Config = struct {
    // Windows SDK Paths
    const sdk_version = "10.0.26100.0";
    const sdk_base = "C:\\Program Files (x86)\\Windows Kits\\10\\bin\\" ++ sdk_version ++ "\\x64";

    // Certificate Settings
    const publisher = "CN=Massoud, O=Massoud, C=IR";
    const cert_password = "zigUWP123!";
    const cert_subject = "zigUWP Self-Signed Certificate";
    const cert_dir = "zig-out/sign";
    const cert_filename = "zigUWP.pfx";

    // Timestamp Server
    const timestamp_url = "http://timestamp.digicert.com";

    // Build Paths
    const bin_dir = "zig-out/bin";
    const package_name = "package";
    const appx_filename = "zigUWP.appx";
    const exe_name = "zigUWP.exe";

    // Source Paths
    const manifest_source = "AppxManifest.xml";
    const assets_source = "../assets/images";
    const libs_source = "../Libs";

    // Package Structure
    const assets_dest = "assets";
    const libs_dest = "Libs";
};

// =====================================================================
// Path Helpers
// =====================================================================

const Paths = struct {
    fn packageDir(b: *std.Build) []const u8 {
        return b.pathJoin(&.{ Config.bin_dir, Config.package_name });
    }

    fn packageAssets(b: *std.Build) []const u8 {
        return b.pathJoin(&.{ packageDir(b), Config.assets_dest });
    }

    fn packageLibs(b: *std.Build) []const u8 {
        return b.pathJoin(&.{ packageDir(b), Config.libs_dest });
    }

    fn appxOutput(b: *std.Build) []const u8 {
        return b.pathJoin(&.{ Config.bin_dir, Config.appx_filename });
    }

    fn certFile(b: *std.Build) []const u8 {
        return b.pathJoin(&.{ Config.cert_dir, Config.cert_filename });
    }
};

// =====================================================================
// PowerShell Command Builder
// =====================================================================

const PSCommand = struct {
    allocator: std.mem.Allocator,
    commands: std.ArrayList([]const u8),

    fn init(allocator: std.mem.Allocator) PSCommand {
        return .{
            .allocator = allocator,
            .commands = std.ArrayList([]const u8).init(allocator),
        };
    }

    fn add(self: *PSCommand, cmd: []const u8) !void {
        try self.commands.append(cmd);
    }

    fn join(self: *PSCommand) ![]const u8 {
        return std.mem.join(self.allocator, "; ", self.commands.items);
    }

    fn deinit(self: *PSCommand) void {
        self.commands.deinit();
    }
};

// =====================================================================
// Build Step Creators
// =====================================================================

/// Creates directory with error handling
fn createDirectory(b: *std.Build, path: []const u8, name: []const u8) *std.Build.Step.Run {
    return b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt(
            \\try {{
            \\    New-Item -Path '{s}' -ItemType Directory -Force | Out-Null
            \\    Write-Host '[OK] Created {s} directory'
            \\}} catch {{
            \\    Write-Error "Failed to create {s}: $_"
            \\    exit 1
            \\}}
        , .{ path, name, name }),
    });
}

/// Copies file with verification
fn copyFile(b: *std.Build, source: []const u8, dest: []const u8, name: []const u8) *std.Build.Step.Run {
    return b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt(
            \\try {{
            \\    if (-not (Test-Path '{s}')) {{
            \\        throw "Source file not found: {s}"
            \\    }}
            \\    Copy-Item -Path '{s}' -Destination '{s}' -Force
            \\    Write-Host '[OK] Copied {s}'
            \\}} catch {{
            \\    Write-Error "Failed to copy {s}: $_"
            \\    exit 1
            \\}}
        , .{ source, source, source, dest, name, name }),
    });
}

/// Copies directory recursively
fn copyDirectory(b: *std.Build, source: []const u8, dest: []const u8, name: []const u8) *std.Build.Step.Run {
    return b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt(
            \\try {{
            \\    if (Test-Path '{s}') {{
            \\        Copy-Item -Path '{s}/*' -Destination '{s}' -Recurse -Force
            \\        Write-Host '[OK] Copied {s} files'
            \\    }} else {{
            \\        Write-Host '[SKIP] {s} directory not found'
            \\    }}
            \\}} catch {{
            \\    Write-Error "Failed to copy {s}: $_"
            \\    exit 1
            \\}}
        , .{ source, source, dest, name, name, name }),
    });
}

/// Updates manifest with publisher information
fn updateManifest(b: *std.Build, manifest_path: []const u8) *std.Build.Step.Run {
    return b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt(
            \\try {{
            \\    $manifestPath = '{s}'
            \\    $publisher = '{s}'
            \\    
            \\    if (-not (Test-Path $manifestPath)) {{
            \\        throw "Manifest file not found: $manifestPath"
            \\    }}
            \\    
            \\    [xml]$xml = Get-Content $manifestPath -Encoding UTF8
            \\    $xml.Package.Identity.Publisher = $publisher
            \\    $xml.Save($manifestPath)
            \\    
            \\    Write-Host '[OK] Updated manifest publisher'
            \\}} catch {{
            \\    Write-Error "Failed to update manifest: $_"
            \\    exit 1
            \\}}
        , .{ manifest_path, Config.publisher }),
    });
}

/// Creates APPX package using MakeAppx
fn createAppxPackage(b: *std.Build) *std.Build.Step.Run {
    const package_dir = Paths.packageDir(b);
    const output_path = Paths.appxOutput(b);

    return b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt(
            \\try {{
            \\    $sdkPath = $env:MAKEAPPX_PATH
            \\    if (-not $sdkPath) {{ $sdkPath = '{s}' }}
            \\    
            \\    $makeAppx = Join-Path $sdkPath 'MakeAppx.exe'
            \\    
            \\    if (-not (Test-Path $makeAppx)) {{
            \\        throw "MakeAppx.exe not found at: $makeAppx"
            \\    }}
            \\    
            \\    Write-Host '[INFO] Creating APPX package...'
            \\    & $makeAppx pack /d '{s}' /p '{s}' /l /o
            \\    
            \\    if ($LASTEXITCODE -ne 0) {{
            \\        throw "MakeAppx failed with exit code: $LASTEXITCODE"
            \\    }}
            \\    
            \\    Write-Host '[OK] Package created successfully'
            \\}} catch {{
            \\    Write-Error "Failed to create package: $_"
            \\    exit 1
            \\}}
        , .{ Config.sdk_base, package_dir, output_path }),
    });
}

/// Signs APPX package (delegates to external script)
fn signAppxPackage(b: *std.Build) *std.Build.Step.Run {
    return b.addSystemCommand(&.{
        "PowerShell",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "sign-appx.ps1",
        "-PackagePath",
        Paths.appxOutput(b),
        "-CertFilePath",
        Paths.certFile(b),
        "-CertSubject",
        Config.cert_subject,
        "-CertPassword",
        Config.cert_password,
        "-PublisherName",
        Config.publisher,
    });
}

///  Installs APPX package
fn installAppxPackage(b: *std.Build) *std.Build.Step.Run {
    const package_path = Paths.appxOutput(b);

    return b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt(
            \\try {{
            \\    $packagePath = '{s}'
            \\    $skipSigning = $env:SKIP_SIGNING -eq 'true'
            \\    
            \\    if (-not (Test-Path $packagePath)) {{
            \\        throw "Package file not found: $packagePath"
            \\    }}
            \\    
            \\    Write-Host '[INFO] Installing package...'
            \\    
            \\    try {{
            \\        Add-AppxPackage -Path $packagePath -ForceUpdateFromAnyVersion
            \\        Write-Host '[OK] Package installed successfully'
            \\    }} catch {{
            \\        Write-Host '[INFO] Trying development mode installation...'
            \\        Add-AppxPackage -Path $packagePath -ForceUpdateFromAnyVersion -DevelopmentMode
            \\        Write-Host '[OK] Package installed in development mode'
            \\    }}
            \\}} catch {{
            \\    Write-Error "Failed to install package: $_"
            \\    Write-Host 'Tip: Enable Developer Mode or set SKIP_SIGNING=true'
            \\    exit 1
            \\}}
        , .{package_path}),
    });
}

// =====================================================================
// Public API
// =====================================================================

/// Creates the main package build step with all dependencies
pub fn createPackageStep(b: *std.Build) *std.Build.Step {
    const package_step = b.step("package", "Create UWP package");

    // Define paths
    const package_dir = Paths.packageDir(b);
    const package_assets = Paths.packageAssets(b);
    const package_libs = Paths.packageLibs(b);
    const manifest_dest = b.pathJoin(&.{ package_dir, "AppxManifest.xml" });
    const exe_source = b.pathJoin(&.{ Config.bin_dir, Config.exe_name });
    const exe_dest = b.pathJoin(&.{ package_dir, Config.exe_name });

    // Create directory structure
    const step_create_package_dir = createDirectory(b, package_dir, "package");
    const step_create_assets_dir = createDirectory(b, package_assets, "assets");
    const step_create_libs_dir = createDirectory(b, package_libs, "libs");

    // Copy files
    const step_copy_exe = copyFile(b, exe_source, exe_dest, "executable");
    const step_copy_manifest = copyFile(b, Config.manifest_source, manifest_dest, "manifest");
    const step_copy_assets = copyDirectory(b, Config.assets_source, package_assets, "assets");
    const step_copy_libs = copyDirectory(b, Config.libs_source, package_libs, "libraries");

    // Update manifest
    const step_update_manifest = updateManifest(b, manifest_dest);

    // Create package
    const step_create_appx = createAppxPackage(b);

    // Build dependency chain
    step_copy_exe.step.dependOn(&step_create_package_dir.step);
    step_copy_manifest.step.dependOn(&step_copy_exe.step);
    step_update_manifest.step.dependOn(&step_copy_manifest.step);
    step_create_assets_dir.step.dependOn(&step_update_manifest.step);
    step_copy_assets.step.dependOn(&step_create_assets_dir.step);
    step_create_libs_dir.step.dependOn(&step_copy_assets.step);
    step_copy_libs.step.dependOn(&step_create_libs_dir.step);
    step_create_appx.step.dependOn(&step_copy_libs.step);

    package_step.dependOn(&step_create_appx.step);

    // Additional steps
    _ = createSignStep(b);
    _ = createInstallStep(b);
    _ = createAllStep(b);

    return package_step;
}

/// Creates certificate generation step
fn createSignStep(b: *std.Build) *std.Build.Step {
    const sign_step = b.step("sign-appx", "Sign UWP package");
    const step_sign = signAppxPackage(b);
    sign_step.dependOn(&step_sign.step);
    return sign_step;
}

/// Creates installation step
fn createInstallStep(b: *std.Build) *std.Build.Step {
    const install_step = b.step("install-appx", "Install UWP package");
    const step_install = installAppxPackage(b);
    install_step.dependOn(&step_install.step);
    return install_step;
}

/// Creates all-in-one step
fn createAllStep(b: *std.Build) *std.Build.Step {
    const all_step = b.step("all-appx", "Build, package, sign and install UWP application");
    const step_sign = signAppxPackage(b);
    const step_install = installAppxPackage(b);

    step_install.step.dependOn(&step_sign.step);
    all_step.dependOn(&step_install.step);

    return all_step;
}

/// Creates clean step
pub fn createCleanStep(b: *std.Build) *std.Build.Step {
    const clean_step = b.step("clean", "Clean build artifacts");
    const clean_cmd = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt(
            \\Write-Host '[INFO] Cleaning build artifacts...'
            \\Remove-Item -Path '{s}' -Recurse -Force -ErrorAction SilentlyContinue
            \\Remove-Item -Path 'zig-cache' -Recurse -Force -ErrorAction SilentlyContinue
            \\Remove-Item -Path '*.appx' -Force -ErrorAction SilentlyContinue
            \\Write-Host '[OK] Clean completed'
        , .{Config.bin_dir}),
    });
    clean_step.dependOn(&clean_cmd.step);
    return clean_step;
}
