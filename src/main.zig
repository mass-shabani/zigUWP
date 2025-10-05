const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;
const HRESULT = windows.HRESULT;
const WINAPI = windows.WINAPI;
const HINSTANCE = windows.HINSTANCE;
const LPWSTR = windows.LPWSTR;

// Windows constants
const SW_SHOW: i32 = 5;

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

// Global allocator (for simplicity in UWP context)
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
        return UWPApplication{
            .allocator = allocator,
            .winrt_system = activation.WinRTSystem.init(),
            .core_app_manager = application_interfaces.CoreApplicationManager.init(allocator),
            .error_handler = error_handling.ErrorHandler.init(allocator),
            .view_source = null,
        };
    }

    pub fn deinit(self: *UWPApplication) void {
        if (self.view_source) |vs| {
            const view_source_interface: *view_interfaces.IFrameworkViewSource = @ptrCast(vs);
            _ = view_source_interface.release();
            self.view_source = null;
        }

        self.core_app_manager.deinit();
        self.error_handler.deinit();
        self.winrt_system.shutdown();
    }

    pub fn startup(self: *UWPApplication) !void {
        outputDebug("=== ZigUWP - Pure WinRT UWP Application ===\n");
        outputDebug("Initializing WinRT systems...\n\n");

        try self.winrt_system.startup();

        outputDebug("WinRT initialization completed successfully\n");
    }

    pub fn createViewSource(self: *UWPApplication) !void {
        self.view_source = try view_source_impl.UWPFrameworkViewSource.create(self.allocator);
        outputDebug("FrameworkViewSource created successfully\n");
    }

    pub fn run(self: *UWPApplication) !void {
        if (self.view_source == null) {
            return error.NoViewSource;
        }

        const core_app = try self.core_app_manager.getCoreApplication();
        defer _ = core_app.release();

        outputDebug("CoreApplication obtained successfully\n");
        outputDebug("\n=== Starting UWP Application ===\n");

        const view_source_interface: *view_interfaces.IFrameworkViewSource = @ptrCast(self.view_source.?);
        _ = view_source_interface.addRef();
        defer _ = view_source_interface.release();

        const hr = core_app.run(view_source_interface);

        if (winrt_core.isSuccess(hr)) {
            outputDebug("CoreApplication::Run succeeded!\n");
        } else {
            const hr_u32 = @as(u32, @bitCast(hr));
            var buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "CoreApplication::Run failed: 0x{X}\n", .{hr_u32}) catch "Error formatting message\n";
            outputDebug(msg);

            const error_context = error_handling.ErrorContext.init(hr, "Run", "ICoreApplication");
            return self.error_handler.handleError(error_context);
        }

        outputDebug("\n=== UWP Application Completed Successfully ===\n");
    }
};

// Helper function to output debug strings (visible in DebugView)
fn outputDebug(message: []const u8) void {
    // Convert to UTF-16 for OutputDebugStringW
    var wide_buffer: [4096]u16 = undefined;
    const wide_len = std.unicode.utf8ToUtf16Le(&wide_buffer, message) catch return;

    if (wide_len < wide_buffer.len) {
        wide_buffer[wide_len] = 0;
        OutputDebugStringW(@ptrCast(&wide_buffer));
    }
}

// Windows API declarations
extern "kernel32" fn OutputDebugStringW(lpOutputString: [*:0]const u16) callconv(WINAPI) void;
extern "kernel32" fn GetModuleHandleW(lpModuleName: ?[*:0]const u16) callconv(WINAPI) ?HINSTANCE;
extern "kernel32" fn GetCommandLineW() callconv(WINAPI) LPWSTR;
extern "kernel32" fn ExitProcess(exit_code: u32) callconv(WINAPI) noreturn;

/// Main entry point for UWP application
/// این تابع توسط Windows برای UWP apps صدا زده می‌شود
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

    outputDebug("\n");
    outputDebug("=====================================\n");
    outputDebug("wWinMain CALLED - UWP app starting!\n");
    outputDebug("=====================================\n");
    outputDebug("\n");

    // Initialize global allocator
    gpa = std.heap.GeneralPurposeAllocator(.{}){};
    global_allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Create and initialize UWP application
    var uwp_app = UWPApplication.init(global_allocator);
    defer uwp_app.deinit();

    // Startup WinRT systems
    uwp_app.startup() catch |err| {
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Failed to startup: {s}\n", .{@errorName(err)}) catch "Startup failed\n";
        outputDebug(msg);
        return 1;
    };

    // Create view source
    uwp_app.createViewSource() catch |err| {
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Failed to create view source: {s}\n", .{@errorName(err)}) catch "View source creation failed\n";
        outputDebug(msg);
        return 1;
    };

    // Run the application
    uwp_app.run() catch |err| {
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Application run failed: {s}\n", .{@errorName(err)}) catch "Run failed\n";
        outputDebug(msg);
        return 1;
    };

    outputDebug("\n");
    outputDebug("=====================================\n");
    outputDebug("UWP Application exiting normally\n");
    outputDebug("=====================================\n");
    outputDebug("\n");

    return 0;
}

/// Export as CRT startup function
/// این تابع entry point واقعی است که Windows loader صدا می‌زند
pub export fn wWinMainCRTStartup() callconv(.C) noreturn {
    outputDebug("wWinMainCRTStartup CALLED by Windows loader\n");

    // Use global extern declarations for Windows APIs
    const hInstance = GetModuleHandleW(null);
    const pCmdLine = GetCommandLineW();

    // اگر hInstance null بود، از undefined استفاده می‌کنیم (نباید اتفاق بیفتد)
    const result = wWinMain(
        hInstance orelse undefined,
        null,
        pCmdLine,
        SW_SHOW,
    );

    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Exiting with code: {}\n", .{result}) catch "Exiting\n";
    outputDebug(msg);

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
    std.debug.print("\n", .{});
    outputDebug("⚠️WARNING: zigUWP, This is a UWP application.");

    return error.UWPAppCannotRunDirectly;
}
