const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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


    // Module testing executable
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

    // Run commands
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_module_test_cmd = b.addRunArtifact(module_test_exe);
    run_module_test_cmd.step.dependOn(b.getInstallStep());

    // Pass arguments to run commands
    if (b.args) |args| {
        run_cmd.addArgs(args);
        run_module_test_cmd.addArgs(args);
    }

    // Build steps
    const run_step = b.step("run", "Run the main UWP application");
    run_step.dependOn(&run_cmd.step);

    const module_test_step = b.step("test-modules", "Test individual modules");
    module_test_step.dependOn(&run_module_test_cmd.step);

    // Unit tests for the modules
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

    // Clean step
    const clean_step = b.step("clean", "Clean build artifacts");
    // Note: Zig build system handles cleaning automatically, so we just create an empty step
    _ = clean_step;

    // Documentation step
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

    // Help step
    const help_step = b.step("help", "Show available build commands");
    const help_cmd = b.addSystemCommand(&[_][]const u8{ "echo", "Available commands:\n" ++
        "  zig build run           - Run the main UWP application\n" ++
        "  zig build test-modules  - Test individual modules\n" ++
        "  zig build test          - Run unit tests\n" ++
        "  zig build docs          - Generate documentation\n" ++
        "  zig build clean         - Clean build artifacts\n" ++
        "  zig build help          - Show this help\n" });
    help_step.dependOn(&help_cmd.step);
}
