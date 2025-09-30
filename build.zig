const std = @import("std");
const appx = @import("build-appx.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // *** Build steps
    // Main UWP executable with modular architecture
    const exe = b.addExecutable(.{
        .name = "zigUWP",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add library search path
    exe.addLibraryPath(b.path("Libs"));

    // Link required Windows libraries for UWP
    exe.linkSystemLibrary("ole32"); // COM support
    exe.linkSystemLibrary("WindowsApp"); // WinRT runtime
    exe.linkSystemLibrary("runtimeobject"); // WinRT runtime objects
    exe.linkSystemLibrary("combase"); // COM base library

    // Link C runtime
    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the main UWP application");
    run_step.dependOn(&run_cmd.step);

    // Create UWP package after installation
    _ = appx.createPackageStep(b);

    // *** Module testing executable
    const module_test_exe = b.addExecutable(.{
        .name = "module_test",
        .root_source_file = b.path("src/test_modules.zig"),
        .target = target,
        .optimize = optimize,
    });

    module_test_exe.addLibraryPath(b.path("Libs"));
    module_test_exe.linkSystemLibrary("ole32");
    module_test_exe.linkSystemLibrary("WindowsApp");
    module_test_exe.linkSystemLibrary("runtimeobject");
    module_test_exe.linkSystemLibrary("combase");
    module_test_exe.linkLibC();

    b.installArtifact(module_test_exe);

    const run_module_test_cmd = b.addRunArtifact(module_test_exe);
    run_module_test_cmd.step.dependOn(b.getInstallStep());

    // Pass arguments to run commands
    if (b.args) |args| {
        run_cmd.addArgs(args);
        run_module_test_cmd.addArgs(args);
    }

    const module_test_step = b.step("test-modules", "Test individual modules");
    module_test_step.dependOn(&run_module_test_cmd.step);

    // *** Unit tests for the modules
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    unit_tests.addLibraryPath(b.path("Libs"));
    unit_tests.linkSystemLibrary("ole32");
    unit_tests.linkSystemLibrary("WindowsApp");
    unit_tests.linkSystemLibrary("runtimeobject");
    unit_tests.linkSystemLibrary("combase");
    unit_tests.linkLibC();

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const unit_test_step = b.step("test", "Run unit tests");
    unit_test_step.dependOn(&run_unit_tests.step);

    // *** Clean step
    _ = appx.createCleanStep(b);

    // *** Documentation step
    const doc_step = b.step("docs", "Generate documentation");
    const doc_obj = b.addObject(.{
        .name = "zigUWP-docs",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .Debug,
    });

    const docs = doc_obj.getEmittedDocs();
    doc_step.dependOn(&b.addInstallDirectory(.{
        .source_dir = docs,
        .install_dir = .prefix,
        .install_subdir = "docs",
    }).step);

    // *** Help step
    const help_step = b.step("help", "Show available build commands");

    // Simple help step using system command
    const help_cmd = b.addSystemCommand(&.{
        "PowerShell",
        "-Command",
        "Write-Host 'Available commands:'; Write-Host '  zig build run           - Run the main UWP application'; Write-Host '  zig build test-modules  - Test individual modules'; Write-Host '  zig build test          - Run unit tests'; Write-Host '  zig build docs          - Generate documentation'; Write-Host '  zig build package       - Create UWP package (appx)'; Write-Host '  zig build sign-appx     - Sign UWP package'; Write-Host '  zig build install-appx  - Install UWP package'; Write-Host '  zig build all-appx      - Build, package, sign and install UWP application'; Write-Host '  zig build clean         - Clean build artifacts'; Write-Host '  zig build clean-all     - Clean build artifacts and packages'; Write-Host '  zig build help          - Show this help'",
    });
    help_step.dependOn(&help_cmd.step);
}
