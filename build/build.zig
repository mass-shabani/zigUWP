// build/build.zig
const std = @import("std");
const appx = @import("build-appx.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ========================================================================
    // Main UWP Executable
    // ========================================================================

    const exe = b.addExecutable(.{
        .name = "zigUWP",
        .root_source_file = b.path("../src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // CRITICAL: Must be Windows subsystem for UWP
    exe.subsystem = .Windows;

    // Add library search path
    exe.addLibraryPath(b.path("../Libs"));

    // Link required libraries
    exe.linkLibC();
    exe.linkSystemLibrary("ole32"); // COM support
    exe.linkSystemLibrary("WindowsApp"); // WinRT runtime
    exe.linkSystemLibrary("runtimeobject"); // WinRT runtime objects
    exe.linkSystemLibrary("combase"); // COM base library

    b.installArtifact(exe);

    // Run command (will show error message if run directly)
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the UWP application (will show error)");
    run_step.dependOn(&run_cmd.step);

    // ========================================================================
    // Package Steps
    // ========================================================================

    _ = appx.createPackageStep(b);

    // ========================================================================
    // Test Logger
    // ========================================================================

    const test_logger_exe = b.addExecutable(.{
        .name = "test_logger",
        .root_source_file = b.path("../src/test_logger.zig"),
        .target = target,
        .optimize = optimize,
    });

    test_logger_exe.subsystem = .Console;
    test_logger_exe.linkLibC();

    b.installArtifact(test_logger_exe);

    const run_test_logger = b.addRunArtifact(test_logger_exe);
    run_test_logger.step.dependOn(b.getInstallStep());

    const test_logger_step = b.step("test-logger", "Test the logger");
    test_logger_step.dependOn(&run_test_logger.step);

    // ========================================================================
    // Clean Step
    // ========================================================================

    _ = appx.createCleanStep(b);

    // ========================================================================
    // Help
    // ========================================================================

    const help_step = b.step("help", "Show available commands");
    const help_cmd = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        \\Write-Host '╔════════════════════════════════════════════════════╗' -ForegroundColor Cyan
        \\Write-Host '║            ZigUWP Build Commands                   ║' -ForegroundColor Cyan
        \\Write-Host '╠════════════════════════════════════════════════════╣' -ForegroundColor Cyan
        \\Write-Host '║                                                    ║' -ForegroundColor White
        \\Write-Host '║  Building:                                         ║' -ForegroundColor White
        \\Write-Host '║    zig build              - Build executable       ║' -ForegroundColor White
        \\Write-Host '║    zig build package      - Create APPX package    ║' -ForegroundColor White
        \\Write-Host '║    zig build sign-appx    - Sign package           ║' -ForegroundColor White
        \\Write-Host '║    zig build install-appx - Install package        ║' -ForegroundColor White
        \\Write-Host '║    zig build all-appx     - Build + Sign + Install ║' -ForegroundColor White
        \\Write-Host '║                                                    ║' -ForegroundColor White
        \\Write-Host '║  Testing:                                          ║' -ForegroundColor White
        \\Write-Host '║    zig build test-logger  - Test logger           ║' -ForegroundColor White
        \\Write-Host '║                                                    ║' -ForegroundColor White
        \\Write-Host '║  Maintenance:                                      ║' -ForegroundColor White
        \\Write-Host '║    zig build clean        - Clean build artifacts ║' -ForegroundColor White
        \\Write-Host '║    zig build help         - Show this help        ║' -ForegroundColor White
        \\Write-Host '║                                                    ║' -ForegroundColor White
        \\Write-Host '╚════════════════════════════════════════════════════╝' -ForegroundColor Cyan
        \\Write-Host ''
        \\Write-Host 'Quick Start:' -ForegroundColor Yellow
        \\Write-Host '  1. zig build all-appx' -ForegroundColor White
        \\Write-Host '  2. Launch from Start Menu: "ZigUWP"' -ForegroundColor White
        \\Write-Host '  3. Check logs: %LOCALAPPDATA%\ziguwp_debug.log' -ForegroundColor White
    });
    help_step.dependOn(&help_cmd.step);
}
