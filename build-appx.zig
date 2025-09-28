const std = @import("std");

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
        b.fmt("Copy-Item -Path '{s}\\zigUWP.exe' -Destination '{s}\\' -Force", .{ bin_dir, package_dir }),
    });

    const copy_manifest = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt("Copy-Item -Path 'assets\\appx\\Package.appxmanifest' -Destination '{s}\\' -Force", .{package_dir}),
    });

    const create_assets_dir = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt("New-Item -Path '{s}\\assets' -ItemType Directory -Force | Out-Null", .{package_dir}),
    });

    const copy_assets = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt("Copy-Item -Path 'assets\\images\\*' -Destination '{s}\\assets\\' -Recurse -Force", .{package_dir}),
    });

    const create_libs_dir = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        b.fmt("New-Item -Path '{s}\\Libs' -ItemType Directory -Force | Out-Null", .{package_dir}),
    });

    const copy_libs = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        "if (Test-Path 'Libs\\*') { Copy-Item -Path 'Libs\\*' -Destination 'zig-out/bin/package/Libs/' -Recurse -Force }",
    });

    const make_appx = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        "if (Get-Command 'MakeAppx' -ErrorAction SilentlyContinue) { MakeAppx pack /d 'zig-out/bin/package' /p 'zig-out/bin/zigUWP.appx' /l } else { Write-Host 'MakeAppx tool not found, skipping package creation' }",
    });

    const sign_appx = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        "if (Get-Command 'SignTool' -ErrorAction SilentlyContinue) { SignTool sign /a /v /s My /t http://timestamp.digicert.com/ 'zig-out/bin/zigUWP.appx' } else { Write-Host 'SignTool not found, skipping package signing' }",
    });

    const install_appx = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        "if (Test-Path 'zig-out/bin/zigUWP.appx') { Add-AppxPackage -Path 'zig-out/bin/zigUWP.appx' -ForceUpdateFromAnyVersion } else { Write-Host 'Package file not found, skipping installation' }",
    });

    copy_exe.step.dependOn(&create_package_dir.step);
    copy_manifest.step.dependOn(&copy_exe.step);
    create_assets_dir.step.dependOn(&copy_manifest.step);
    copy_assets.step.dependOn(&create_assets_dir.step);
    create_libs_dir.step.dependOn(&copy_assets.step);
    copy_libs.step.dependOn(&create_libs_dir.step);
    make_appx.step.dependOn(&copy_libs.step);
    sign_appx.step.dependOn(&make_appx.step);
    install_appx.step.dependOn(&sign_appx.step);
    package_step.dependOn(&install_appx.step);

    const sign_step = b.step("sign-appx", "Sign UWP package");
    sign_step.dependOn(&make_appx.step);
    sign_step.dependOn(&sign_appx.step);

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
        "Remove-Item -Path 'zig-out' -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path 'zig-cache' -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item '*.appx' -Force -ErrorAction SilentlyContinue",
    });
    clean_step.dependOn(&clean_cmd.step);
    return clean_step;
}
