const std = @import("std");
const winrt_core = @import("../core/winrt_core.zig");
const com_base = @import("../core/com_base.zig");
const view_interfaces = @import("../interfaces/view.zig");
const window_interfaces = @import("../interfaces/window.zig");
const application_interfaces = @import("../interfaces/application.zig");
const error_handling = @import("../utils/error_handling.zig");

const WINAPI = winrt_core.WINAPI;
const HRESULT = winrt_core.HRESULT;
const GUID = winrt_core.GUID;
const HSTRING = winrt_core.HSTRING;
const TrustLevel = winrt_core.TrustLevel;
const S_OK = winrt_core.S_OK;

// Our custom FrameworkView implementation
pub const UWPFrameworkView = struct {
    vtbl: *const view_interfaces.IFrameworkView.IFrameworkViewVtbl,
    base: com_base.ComObjectBase,

    // State management
    app_view: ?*application_interfaces.ICoreApplicationView,
    core_window: ?*window_interfaces.ICoreWindow,
    window_manager: ?*window_interfaces.WindowManager,
    error_handler: ?*error_handling.ErrorHandler,

    const Self = @This();

    pub fn create(allocator: std.mem.Allocator) !*Self {
        const instance = try allocator.create(Self);
        instance.* = Self{
            .vtbl = &VTable,
            .base = com_base.ComObjectBase.init(allocator),
            .app_view = null,
            .core_window = null,
            .window_manager = null,
            .error_handler = null,
        };

        // Initialize window manager
        const window_manager = try allocator.create(window_interfaces.WindowManager);
        window_manager.* = window_interfaces.WindowManager.init(allocator);
        instance.window_manager = window_manager;

        // Initialize error handler
        const error_handler = try allocator.create(error_handling.ErrorHandler);
        error_handler.* = error_handling.ErrorHandler.init(allocator);
        instance.error_handler = error_handler;

        return instance;
    }

    pub fn destroy(self: *Self) void {
        // Clean up resources
        if (self.window_manager) |wm| {
            wm.deinit();
            self.base.allocator.destroy(wm);
        }

        if (self.error_handler) |eh| {
            eh.deinit();
            self.base.allocator.destroy(eh);
        }

        if (self.core_window) |window| {
            _ = window.release();
        }

        if (self.app_view) |view| {
            _ = view.release();
        }

        const allocator = self.base.allocator;
        allocator.destroy(self);
    }

    // IUnknown implementation
    fn queryInterface(self: *view_interfaces.IFrameworkView, riid: *const GUID, ppvObject: *?*anyopaque) callconv(WINAPI) HRESULT {
        const supported_interfaces = [_]GUID{
            com_base.IID_IUnknown,
            com_base.IID_IInspectable,
            view_interfaces.IID_IFrameworkView,
        };

        return com_base.ComObjectBase.queryInterfaceBase(riid, ppvObject, self, &supported_interfaces);
    }

    fn addRef(self: *view_interfaces.IFrameworkView) callconv(WINAPI) u32 {
        const instance: *Self = @alignCast(@ptrCast(self));
        return instance.base.addRef();
    }

    fn release(self: *view_interfaces.IFrameworkView) callconv(WINAPI) u32 {
        const instance: *Self = @alignCast(@ptrCast(self));
        const ref_count = instance.base.release();

        if (ref_count == 0) {
            instance.destroy();
        }

        return ref_count;
    }

    // IInspectable implementation
    fn getIids(self: *view_interfaces.IFrameworkView, iidCount: *u32, iids: *?**GUID) callconv(WINAPI) HRESULT {
        _ = self;
        return com_base.InspectableHelpers.getIidsEmpty(iidCount, iids);
    }

    fn getRuntimeClassName(self: *view_interfaces.IFrameworkView, className: *HSTRING) callconv(WINAPI) HRESULT {
        _ = self;
        return com_base.InspectableHelpers.getRuntimeClassNameEmpty(className);
    }

    fn getTrustLevel(self: *view_interfaces.IFrameworkView, trustLevel: *TrustLevel) callconv(WINAPI) HRESULT {
        _ = self;
        return com_base.InspectableHelpers.getTrustLevelBasic(trustLevel);
    }

    // IFrameworkView implementation
    fn initialize(self: *view_interfaces.IFrameworkView, app_view: *application_interfaces.ICoreApplicationView) callconv(WINAPI) HRESULT {
        const instance: *Self = @alignCast(@ptrCast(self));

        std.debug.print("FrameworkView: Initialize called\n", .{});

        // Store the application view
        if (instance.app_view) |old_view| {
            _ = old_view.release();
        }

        instance.app_view = app_view;
        _ = app_view.addRef();

        std.debug.print("FrameworkView: Initialize completed successfully\n", .{});
        return S_OK;
    }

    fn setWindow(self: *view_interfaces.IFrameworkView, window: *window_interfaces.ICoreWindow) callconv(WINAPI) HRESULT {
        const instance: *Self = @alignCast(@ptrCast(self));

        std.debug.print("FrameworkView: SetWindow called\n", .{});

        // Store the core window
        if (instance.core_window) |old_window| {
            _ = old_window.release();
        }

        instance.core_window = window;
        _ = window.addRef();

        // Set up window manager
        if (instance.window_manager) |wm| {
            wm.setWindow(window) catch |err| {
                std.debug.print("Failed to set window in window manager: {}\n", .{err});
                return @bitCast(winrt_core.E_FAIL);
            };
        }

        std.debug.print("FrameworkView: SetWindow completed successfully\n", .{});
        return S_OK;
    }

    fn load(self: *view_interfaces.IFrameworkView, entryPoint: HSTRING) callconv(WINAPI) HRESULT {
        const instance: *Self = @alignCast(@ptrCast(self));
        _ = instance;
        _ = entryPoint;

        std.debug.print("FrameworkView: Load called\n", .{});

        // Here we would typically load application resources, initialize UI, etc.
        // For our demo, we'll just log that loading is complete

        std.debug.print("FrameworkView: Load completed successfully\n", .{});
        return S_OK;
    }

    fn run(self: *view_interfaces.IFrameworkView) callconv(WINAPI) HRESULT {
        const instance: *Self = @alignCast(@ptrCast(self));

        std.debug.print("FrameworkView: Run called - Starting UWP application main loop\n", .{});

        // Activate the window
        if (instance.window_manager) |wm| {
            wm.activateWindow() catch |err| {
                std.debug.print("Failed to activate window: {}\n", .{err});
                return @bitCast(winrt_core.E_FAIL);
            };

            // Print window information
            const window_info = wm.getWindowInfo();
            std.debug.print("Window Info:\n", .{});
            std.debug.print("  Has Window: {}\n", .{window_info.has_window});
            std.debug.print("  Has Dispatcher: {}\n", .{window_info.has_dispatcher});
            std.debug.print("  Is Activated: {}\n", .{window_info.is_activated});
            std.debug.print("  Is Visible: {}\n", .{window_info.is_visible});
            std.debug.print("  Size: {}x{}\n", .{ window_info.width, window_info.height });

            std.debug.print("UWP Window should now be visible!\n", .{});
            std.debug.print("Starting message loop...\n", .{});

            // Run the message loop
            wm.runMessageLoop() catch |err| {
                std.debug.print("Message loop failed: {}\n", .{err});
                return @bitCast(winrt_core.E_FAIL);
            };

            std.debug.print("Message loop completed\n", .{});
        } else {
            std.debug.print("ERROR: No window manager available\n", .{});
            return @bitCast(winrt_core.E_FAIL);
        }

        std.debug.print("FrameworkView: Run completed successfully\n", .{});
        return S_OK;
    }

    fn uninitialize(self: *view_interfaces.IFrameworkView) callconv(WINAPI) HRESULT {
        const instance: *Self = @alignCast(@ptrCast(self));

        std.debug.print("FrameworkView: Uninitialize called\n", .{});

        // Clean up window manager
        if (instance.window_manager) |wm| {
            wm.deinit();
        }

        // Release window
        if (instance.core_window) |window| {
            _ = window.release();
            instance.core_window = null;
        }

        // Release app view
        if (instance.app_view) |view| {
            _ = view.release();
            instance.app_view = null;
        }

        std.debug.print("FrameworkView: Uninitialize completed successfully\n", .{});
        return S_OK;
    }

    // VTable for this implementation
    const VTable = view_interfaces.IFrameworkView.IFrameworkViewVtbl{
        .QueryInterface = queryInterface,
        .AddRef = addRef,
        .Release = release,
        .GetIids = getIids,
        .GetRuntimeClassName = getRuntimeClassName,
        .GetTrustLevel = getTrustLevel,
        .Initialize = initialize,
        .SetWindow = setWindow,
        .Load = load,
        .Run = run,
        .Uninitialize = uninitialize,
    };
};
