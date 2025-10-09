// src/main.zig
// Entry point for ZigUWP application
// This is a Pure UWP app that uses WinRT CoreApplication

const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;

// Core modules
const winrt = @import("core/winrt_core.zig");
const activation = @import("core/activation.zig");
const logger = @import("utils/debug_logger.zig");

// Interfaces
const app_interfaces = @import("interfaces/application.zig");
const view_interfaces = @import("interfaces/view.zig");

// Implementation
const view_source = @import("implementation/view_source.zig");

// ============================================================================
// Windows API Declarations
// ============================================================================

extern "kernel32" fn GetModuleHandleW(?[*:0]const u16) callconv(windows.WINAPI) ?windows.HINSTANCE;
extern "kernel32" fn GetCommandLineW() callconv(windows.WINAPI) [*:0]u16;
extern "kernel32" fn ExitProcess(u32) callconv(windows.WINAPI) noreturn;

extern "user32" fn MessageBoxW(
    ?windows.HWND,
    [*:0]const u16,
    [*:0]const u16,
    u32,
) callconv(windows.WINAPI) i32;

const MB_OK: u32 = 0x00000000;
const MB_ICONINFORMATION: u32 = 0x00000040;
const MB_ICONERROR: u32 = 0x00000010;

// ============================================================================
// Helper Functions
// ============================================================================

fn showMessageBox(title: []const u8, message: []const u8, is_error: bool) void {
    var title_wide: [256]u16 = undefined;
    var message_wide: [1024]u16 = undefined;

    const title_len = std.unicode.utf8ToUtf16Le(&title_wide, title) catch return;
    const message_len = std.unicode.utf8ToUtf16Le(&message_wide, message) catch return;

    if (title_len < title_wide.len and message_len < message_wide.len) {
        title_wide[title_len] = 0;
        message_wide[message_len] = 0;

        const flags = if (is_error) MB_OK | MB_ICONERROR else MB_OK | MB_ICONINFORMATION;
        _ = MessageBoxW(null, @ptrCast(&message_wide), @ptrCast(&title_wide), flags);
    }
}

// ============================================================================
// Main Application Logic
// ============================================================================

fn runUWPApplication(allocator: std.mem.Allocator) !void {
    logger.separator('=');
    logger.info("ZigUWP - Pure WinRT Application", .{});
    logger.separator('=');

    // Step 1: Initialize WinRT Runtime
    logger.info("Step 1: Initializing WinRT runtime", .{});
    var runtime = activation.Runtime.init();
    defer runtime.shutdown();

    try runtime.startup();

    // Step 2: Create ViewSource
    logger.info("Step 2: Creating IFrameworkViewSource", .{});
    const view_source_ptr = try view_source.ViewSource.create(allocator);
    defer _ = view_source_ptr.release();

    // Step 3: Get CoreApplication
    logger.info("Step 3: Getting CoreApplication singleton", .{});

    const core_app_ptr = try activation.ActivationFactory.get(
        allocator,
        activation.RuntimeClass.CORE_APPLICATION,
        &app_interfaces.IID_ICoreApplication,
    );

    const core_app: *app_interfaces.ICoreApplication = @ptrCast(@alignCast(core_app_ptr));
    defer _ = core_app.release();

    logger.info("CoreApplication obtained successfully", .{});

    // Step 4: Run the application
    logger.separator('=');
    logger.info("Step 4: Starting CoreApplication.Run()", .{});
    logger.info("This will call ViewSource.CreateView()", .{});
    logger.info("Then IFrameworkView lifecycle methods", .{});
    logger.separator('=');

    const hr = core_app.run(view_source_ptr);

    if (winrt.SUCCEEDED(hr)) {
        logger.info("CoreApplication.Run() completed successfully!", .{});
    } else {
        logger.err("CoreApplication.Run() failed: 0x{X:0>8}", .{@as(u32, @bitCast(hr))});
        return error.CoreApplicationRunFailed;
    }

    logger.separator('=');
    logger.info("Application exiting normally", .{});
    logger.separator('=');
}

// ============================================================================
// wWinMain - Windows Entry Point for GUI apps
// ============================================================================

pub fn wWinMain(
    _: windows.HINSTANCE,
    _: ?windows.HINSTANCE,
    _: [*:0]u16,
    _: i32,
) callconv(windows.WINAPI) i32 {
    // Create allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize logger
    logger.initGlobalLogger(allocator) catch |err| {
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(
            &buf,
            "Failed to initialize logger: {s}",
            .{@errorName(err)},
        ) catch "Logger init failed";
        showMessageBox("ZigUWP Error", msg, true);
        return 1;
    };
    defer logger.deinitGlobalLogger(allocator);

    // Log system information
    if (logger.getLogger()) |log| {
        log.logSystemInfo();
    }

    // Show startup notification
    logger.info("Showing startup notification", .{});
    showMessageBox(
        "ZigUWP Starting",
        "ZigUWP application is initializing...\n\n" ++
            "Logs: %LOCALAPPDATA%\\ziguwp_debug.log",
        false,
    );

    // Run UWP application
    runUWPApplication(allocator) catch |err| {
        logger.critical("Application failed: {s}", .{@errorName(err)});

        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(
            &buf,
            "Application failed:\n{s}\n\nCheck log file for details.",
            .{@errorName(err)},
        ) catch "Application failed";
        showMessageBox("ZigUWP Error", msg, true);
        return 1;
    };

    logger.info("Application completed successfully", .{});
    return 0;
}

// ============================================================================
// wWinMainCRTStartup - CRT Entry Point
// ============================================================================

pub export fn wWinMainCRTStartup() callconv(.C) noreturn {
    const hInstance = GetModuleHandleW(null);
    const pCmdLine = GetCommandLineW();

    // HINSTANCE can be null in some cases, provide a dummy value
    const instance = hInstance orelse blk: {
        // Create a non-zero dummy HINSTANCE
        const dummy_addr: usize = 0x400000; // Typical base address
        break :blk @as(windows.HINSTANCE, @ptrFromInt(dummy_addr));
    };

    const result = wWinMain(
        instance,
        null,
        pCmdLine,
        5, // SW_SHOW
    );

    ExitProcess(@intCast(result));
}

// ============================================================================
// main() - For error messages when run from CLI
// ============================================================================

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("⚠️  This is a UWP application!\n", .{});
    std.debug.print("⚠️  Cannot be run from command line.\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("To run:\n", .{});
    std.debug.print("  1. Build package: zig build package\n", .{});
    std.debug.print("  2. Install: zig build install-appx\n", .{});
    std.debug.print("  3. Launch from Start Menu\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("For debugging:\n", .{});
    std.debug.print("  - Use DebugView (run as Admin)\n", .{});
    std.debug.print("  - Check: %%LOCALAPPDATA%%\\ziguwp_debug.log\n", .{});
    std.debug.print("\n", .{});

    return error.UWPApplicationCannotRunDirectly;
}
