// src/main.zig
const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;
const HRESULT = windows.HRESULT;
const WINAPI = windows.WINAPI;
const HINSTANCE = windows.HINSTANCE;
const LPWSTR = windows.LPWSTR;

// Windows constants
const SW_SHOW: i32 = 5;

// Import debug logger
const logger = @import("utils/debug_logger.zig");

// Import our modular WinRT components
const winrt_core = @import("core/winrt_core.zig");
const activation = @import("core/activation.zig");
const com_base = @import("core/com_base.zig");
const application_interfaces = @import("interfaces/application.zig");
const view_interfaces = @import("interfaces/view.zig");
const framework_view_impl = @import("implementation/framework_view.zig");
const view_source_impl = @import("implementation/view_source.zig");
const error_handling = @import("utils/error_handling.zig");
const hstring = @import("utils/hstring.zig");
const window_interfaces = @import("interfaces/window.zig");

// Global allocator
var gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;
var global_allocator: std.mem.Allocator = undefined;

// UWP Application Manager
const UWPApplication = struct {
    allocator: std.mem.Allocator,
    winrt_system: activation.WinRTSystem,
    core_app_manager: application_interfaces.CoreApplicationManager,
    error_handler: error_handling.ErrorHandler,
    view_source: ?*view_source_impl.UWPFrameworkViewSource,

    pub fn init(allocator: std.mem.Allocator) UWPApplication {
        logger.info("Creating UWPApplication instance", .{});

        return UWPApplication{
            .allocator = allocator,
            .winrt_system = activation.WinRTSystem.init(),
            .core_app_manager = application_interfaces.CoreApplicationManager.init(allocator),
            .error_handler = error_handling.ErrorHandler.init(allocator),
            .view_source = null,
        };
    }

    pub fn deinit(self: *UWPApplication) void {
        logger.info("Cleaning up UWPApplication", .{});

        if (self.view_source) |vs| {
            logger.debug("Releasing view source", .{});
            const view_source_interface: *view_interfaces.IFrameworkViewSource = @ptrCast(vs);
            _ = view_source_interface.release();
            self.view_source = null;
        }

        logger.debug("Deinitializing core app manager", .{});
        self.core_app_manager.deinit();

        logger.debug("Deinitializing error handler", .{});
        self.error_handler.deinit();

        logger.debug("Shutting down WinRT system", .{});
        self.winrt_system.shutdown();

        logger.info("UWPApplication cleanup complete", .{});
    }

    pub fn startup(self: *UWPApplication) !void {
        logger.separator('=');
        logger.info("ZigUWP - Pure WinRT UWP Application", .{});
        logger.separator('=');

        logger.info("Initializing WinRT systems...", .{});

        self.winrt_system.startup() catch |err| {
            logger.err("WinRT startup failed: {s}", .{@errorName(err)});
            return err;
        };

        logger.info("WinRT initialization completed successfully", .{});
    }

    pub fn createViewSource(self: *UWPApplication) !void {
        logger.info("Creating FrameworkViewSource...", .{});

        self.view_source = view_source_impl.UWPFrameworkViewSource.create(self.allocator) catch |err| {
            logger.err("FrameworkViewSource creation failed: {s}", .{@errorName(err)});
            return err;
        };

        logger.info("FrameworkViewSource created successfully", .{});
    }

    pub fn run(self: *UWPApplication) !void {
        if (self.view_source == null) {
            logger.err("No view source available", .{});
            return error.NoViewSource;
        }

        logger.info("Obtaining CoreApplication interface...", .{});

        const core_app = self.core_app_manager.getCoreApplication() catch |err| {
            logger.err("Failed to get CoreApplication: {s}", .{@errorName(err)});
            return err;
        };
        defer _ = core_app.release();

        logger.info("CoreApplication obtained successfully", .{});
        logger.separator('=');
        logger.info("Starting UWP Application Main Loop", .{});
        logger.separator('=');

        const view_source_interface: *view_interfaces.IFrameworkViewSource = @ptrCast(self.view_source.?);
        _ = view_source_interface.addRef();
        defer _ = view_source_interface.release();

        logger.debug("Calling CoreApplication.Run()...", .{});
        const hr = core_app.run(view_source_interface);

        if (winrt_core.isSuccess(hr)) {
            logger.info("CoreApplication::Run succeeded!", .{});
        } else {
            const hr_u32 = @as(u32, @bitCast(hr));
            logger.err("CoreApplication::Run failed: 0x{X:0>8}", .{hr_u32});
            logger.logHRESULT(hr, "ICoreApplication::Run");

            const error_context = error_handling.ErrorContext.init(hr, "Run", "ICoreApplication");
            return self.error_handler.handleError(error_context);
        }

        logger.separator('=');
        logger.info("UWP Application Completed Successfully", .{});
        logger.separator('=');
    }
};

// Windows API declarations
extern "kernel32" fn OutputDebugStringW(lpOutputString: [*:0]const u16) callconv(WINAPI) void;
extern "kernel32" fn GetModuleHandleW(lpModuleName: ?[*:0]const u16) callconv(WINAPI) ?HINSTANCE;
extern "kernel32" fn GetCommandLineW() callconv(WINAPI) LPWSTR;
extern "kernel32" fn ExitProcess(exit_code: u32) callconv(WINAPI) noreturn;
extern "user32" fn MessageBoxW(
    hWnd: ?windows.HWND,
    lpText: [*:0]const u16,
    lpCaption: [*:0]const u16,
    uType: u32,
) callconv(WINAPI) i32;

// MessageBox constants
const MB_OK: u32 = 0x00000000;
const MB_ICONINFORMATION: u32 = 0x00000040;
const MB_ICONERROR: u32 = 0x00000010;

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

/// Main entry point for UWP application
pub fn wWinMain(
    hInstance: HINSTANCE,
    hPrevInstance: ?HINSTANCE,
    pCmdLine: LPWSTR,
    nCmdShow: i32,
) callconv(WINAPI) i32 {
    _ = hInstance;
    _ = hPrevInstance;
    _ = pCmdLine;
    _ = nCmdShow;

    // Initialize global allocator
    gpa = std.heap.GeneralPurposeAllocator(.{}){};
    global_allocator = gpa.allocator();
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            // در production این را لاگ کنید
        }
    }

    // Initialize global logger - اولین کاری که باید انجام شود!
    logger.initGlobalLogger(global_allocator) catch |err| {
        // اگر logger init نشد، با MessageBox خطا را نشان بده
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Failed to initialize logger: {s}", .{@errorName(err)}) catch "Logger init failed";
        showMessageBox("ZigUWP Error", msg, true);
        return 1;
    };
    defer logger.deinitGlobalLogger(global_allocator);

    // حالا می‌توانیم لاگ کنیم!
    logger.separator('=');
    logger.info("wWinMain ENTRY POINT", .{});
    logger.separator('=');

    // Log system information
    if (logger.getLogger()) |log| {
        log.logSystemInfo();
    }

    // Show startup message box
    logger.info("Showing startup message box", .{});
    showMessageBox(
        "ZigUWP Starting",
        "ZigUWP application is initializing...\n\nCheck logs at:\n%LOCALAPPDATA%\\ziguwp_debug.log",
        false,
    );

    // Create and initialize UWP application
    logger.info("Creating UWP application instance", .{});
    var uwp_app = UWPApplication.init(global_allocator);
    defer {
        logger.info("Deinitializing UWP application", .{});
        uwp_app.deinit();
    }

    // Startup WinRT systems
    logger.info("Starting up WinRT systems", .{});
    uwp_app.startup() catch |err| {
        logger.critical("Failed to startup WinRT: {s}", .{@errorName(err)});

        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Failed to startup WinRT:\n{s}", .{@errorName(err)}) catch "Startup failed";
        showMessageBox("ZigUWP Error", msg, true);
        return 1;
    };

    // Create view source
    logger.info("Creating view source", .{});
    uwp_app.createViewSource() catch |err| {
        logger.critical("Failed to create view source: {s}", .{@errorName(err)});

        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Failed to create view source:\n{s}", .{@errorName(err)}) catch "View source creation failed";
        showMessageBox("ZigUWP Error", msg, true);
        return 1;
    };

    // Run the application
    logger.info("Running application main loop", .{});
    uwp_app.run() catch |err| {
        logger.critical("Application run failed: {s}", .{@errorName(err)});

        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Application failed to run:\n{s}", .{@errorName(err)}) catch "Run failed";
        showMessageBox("ZigUWP Error", msg, true);
        return 1;
    };

    logger.separator('=');
    logger.info("UWP Application Exiting Normally", .{});
    logger.separator('=');

    return 0;
}

/// Export as CRT startup function
pub export fn wWinMainCRTStartup() callconv(.C) noreturn {
    // اولین پیام - قبل از logger
    const first_msg = "wWinMainCRTStartup CALLED - Entry point reached!\n";
    var wide_buffer: [256]u16 = undefined;
    if (std.unicode.utf8ToUtf16Le(&wide_buffer, first_msg)) |len| {
        if (len < wide_buffer.len) {
            wide_buffer[len] = 0;
            OutputDebugStringW(@ptrCast(&wide_buffer));
        }
    } else |_| {}

    const hInstance = GetModuleHandleW(null);
    const pCmdLine = GetCommandLineW();

    const result = wWinMain(
        hInstance orelse undefined,
        null,
        pCmdLine,
        SW_SHOW,
    );

    // Log قبل از exit
    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Exiting with code: {}\n", .{result}) catch "Exiting\n";
    var wide_buf: [256]u16 = undefined;
    if (std.unicode.utf8ToUtf16Le(&wide_buf, msg)) |len| {
        if (len < wide_buf.len) {
            wide_buf[len] = 0;
            OutputDebugStringW(@ptrCast(&wide_buf));
        }
    } else |_| {}

    ExitProcess(@intCast(result));
}

// برای سازگاری، اگر کسی به اشتباه با zig build run اجرا کند
pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("⚠️  WARNING: This is a UWP application!\n", .{});
    std.debug.print("⚠️  It cannot be run directly from command line.\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("To run this application:\n", .{});
    std.debug.print("  1. Build and package: zig build all-appx\n", .{});
    std.debug.print("  2. Find it in Start Menu: 'ZigUWP'\n", .{});
    std.debug.print("  3. Or use: explorer.exe shell:AppsFolder\\...\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("For debugging:\n", .{});
    std.debug.print("  1. Download DebugView from Microsoft Sysinternals\n", .{});
    std.debug.print("  2. Run DebugView as Administrator\n", .{});
    std.debug.print("  3. Enable: Capture > Capture Global Win32\n", .{});
    std.debug.print("  4. Launch the UWP app from Start Menu\n", .{});
    std.debug.print("  5. Watch logs in DebugView\n", .{});
    std.debug.print("  6. Or check: %LOCALAPPDATA%\\ziguwp_debug.log\n", .{});
    std.debug.print("\n", .{});

    return error.UWPAppCannotRunDirectly;
}
