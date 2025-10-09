// src/implementation/framework_view.zig
// Implementation of IFrameworkView - the heart of UWP application lifecycle
// This handles: Initialize, SetWindow, Load, Run, Uninitialize

const std = @import("std");
const winrt = @import("../core/winrt_core.zig");
const com = @import("../core/com_base.zig");
const view_interfaces = @import("../interfaces/view.zig");
const app_interfaces = @import("../interfaces/application.zig");
const window_interfaces = @import("../interfaces/window.zig");
const logger = @import("../utils/debug_logger.zig");

// ============================================================================
// FrameworkView Implementation
// ============================================================================

pub const FrameworkView = struct {
    // COM object
    com_obj: com.ComObject,

    // IFrameworkView interface
    framework_view_vtbl: view_interfaces.IFrameworkView.VTable,

    // State
    app_view: ?*app_interfaces.ICoreApplicationView,
    core_window: ?*window_interfaces.ICoreWindow,
    dispatcher: ?*window_interfaces.ICoreDispatcher,

    const Self = @This();

    /// Create new FrameworkView instance
    pub fn create(allocator: std.mem.Allocator) !*view_interfaces.IFrameworkView {
        logger.info("Creating FrameworkView...", .{});

        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = Self{
            .com_obj = com.ComObject.init(allocator),
            .framework_view_vtbl = .{
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
            },
            .app_view = null,
            .core_window = null,
            .dispatcher = null,
        };

        logger.debug("FrameworkView created successfully", .{});

        // Return as IFrameworkView interface
        return @ptrCast(&self.framework_view_vtbl);
    }

    /// Get Self from interface pointer
    fn getSelf(iface: *view_interfaces.IFrameworkView) *Self {
        const iface_vtable: *view_interfaces.IFrameworkView.VTable = @ptrCast(iface);
        return @fieldParentPtr("framework_view_vtbl", iface_vtable);
    }

    // ========================================================================
    // IUnknown Implementation
    // ========================================================================

    fn queryInterface(
        iface: *view_interfaces.IFrameworkView,
        riid: *const winrt.GUID,
        ppv: *?*anyopaque,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        const self = getSelf(iface);
        _ = self;

        const supported_iids = [_]winrt.GUID{
            com.IID_IUnknown,
            com.IID_IInspectable,
            view_interfaces.IID_IFrameworkView,
        };

        return com.queryInterfaceHelper(riid, ppv, iface, &supported_iids);
    }

    fn addRef(
        iface: *view_interfaces.IFrameworkView,
    ) callconv(winrt.WINAPI) u32 {
        const self = getSelf(iface);
        return self.com_obj.addRef();
    }

    fn release(
        iface: *view_interfaces.IFrameworkView,
    ) callconv(winrt.WINAPI) u32 {
        const self = getSelf(iface);
        const count = self.com_obj.release();

        if (count == 0) {
            logger.debug("FrameworkView ref count = 0, cleaning up", .{});

            // Release held references
            if (self.dispatcher) |d| {
                _ = d.release();
            }
            if (self.core_window) |w| {
                _ = w.release();
            }
            if (self.app_view) |v| {
                _ = v.release();
            }

            const allocator = self.com_obj.allocator;
            allocator.destroy(self);
        }

        return count;
    }

    // ========================================================================
    // IInspectable Implementation
    // ========================================================================

    fn getIids(
        iface: *view_interfaces.IFrameworkView,
        count: *u32,
        iids: *?[*]winrt.GUID,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        return com.InspectableDefaults.getIidsEmpty(@ptrCast(iface), count, iids);
    }

    fn getRuntimeClassName(
        iface: *view_interfaces.IFrameworkView,
        name: *winrt.HSTRING,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        return com.InspectableDefaults.getRuntimeClassNameEmpty(@ptrCast(iface), name);
    }

    fn getTrustLevel(
        iface: *view_interfaces.IFrameworkView,
        level: *winrt.TrustLevel,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        return com.InspectableDefaults.getTrustLevelBase(@ptrCast(iface), level);
    }

    // ========================================================================
    // IFrameworkView Implementation
    // ========================================================================

    fn initialize(
        iface: *view_interfaces.IFrameworkView,
        applicationView: *app_interfaces.ICoreApplicationView,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        const self = getSelf(iface);

        logger.info("FrameworkView.Initialize called", .{});

        // Store application view
        if (self.app_view) |old| {
            _ = old.release();
        }

        self.app_view = applicationView;
        _ = applicationView.addRef();

        logger.info("FrameworkView initialized successfully", .{});
        return winrt.S_OK;
    }

    fn setWindow(
        iface: *view_interfaces.IFrameworkView,
        window: *window_interfaces.ICoreWindow,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        const self = getSelf(iface);

        logger.info("FrameworkView.SetWindow called", .{});

        // Store core window
        if (self.core_window) |old| {
            _ = old.release();
        }

        self.core_window = window;
        _ = window.addRef();

        // Get dispatcher
        var dispatcher: ?*window_interfaces.ICoreDispatcher = null;
        const hr = window.getDispatcher(&dispatcher);

        if (winrt.SUCCEEDED(hr) and dispatcher != null) {
            if (self.dispatcher) |old| {
                _ = old.release();
            }
            self.dispatcher = dispatcher;
            logger.debug("Dispatcher obtained successfully", .{});
        } else {
            logger.warn("Failed to get dispatcher: 0x{X:0>8}", .{@as(u32, @bitCast(hr))});
        }

        logger.info("FrameworkView.SetWindow completed", .{});
        return winrt.S_OK;
    }

    fn load(
        iface: *view_interfaces.IFrameworkView,
        entryPoint: winrt.HSTRING,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        const self = getSelf(iface);
        _ = self;
        _ = entryPoint;

        logger.info("FrameworkView.Load called", .{});

        // In a real app, you would:
        // - Load XAML resources
        // - Initialize UI components
        // - Load application state

        logger.info("FrameworkView.Load completed", .{});
        return winrt.S_OK;
    }

    fn run(
        iface: *view_interfaces.IFrameworkView,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        const self = getSelf(iface);

        logger.info("==================================", .{});
        logger.info("FrameworkView.Run - MAIN LOOP", .{});
        logger.info("==================================", .{});

        // Activate window
        if (self.core_window) |window| {
            logger.info("Activating CoreWindow...", .{});
            const activate_hr = window.activate();

            if (winrt.SUCCEEDED(activate_hr)) {
                logger.info("Window activated successfully!", .{});
            } else {
                logger.warn("Window activation returned: 0x{X:0>8}", .{@as(u32, @bitCast(activate_hr))});
            }

            // Check visibility
            var is_visible: bool = false;
            const visible_hr = window.getVisible(&is_visible);
            if (winrt.SUCCEEDED(visible_hr)) {
                logger.info("Window visible: {}", .{is_visible});
            }

            // Get bounds
            var bounds: window_interfaces.Rect = undefined;
            const bounds_hr = window.getBounds(&bounds);
            if (winrt.SUCCEEDED(bounds_hr)) {
                logger.info("Window bounds: {d}x{d} at ({d}, {d})", .{
                    bounds.width,
                    bounds.height,
                    bounds.x,
                    bounds.y,
                });
            }
        } else {
            logger.err("No CoreWindow available!", .{});
            return @bitCast(winrt.E_FAIL);
        }

        // Run message loop
        if (self.dispatcher) |dispatcher| {
            logger.info("Starting message loop...", .{});
            logger.info("Window should now be visible!", .{});

            var message_count: u32 = 0;
            var running = true;

            while (running) {
                // Process all pending events
                const hr = dispatcher.processEvents(.ProcessAllIfPresent);

                if (winrt.FAILED(hr)) {
                    logger.err("ProcessEvents failed: 0x{X:0>8}", .{@as(u32, @bitCast(hr))});
                    break;
                }

                message_count += 1;

                // Log every 1000 iterations
                if (message_count % 1000 == 0) {
                    logger.debug("Message loop iteration: {d}", .{message_count});
                }

                // Check if window is still visible
                if (self.core_window) |window| {
                    var is_visible: bool = false;
                    _ = window.getVisible(&is_visible);

                    if (!is_visible) {
                        logger.info("Window no longer visible, exiting", .{});
                        running = false;
                    }
                }

                // Small sleep to prevent 100% CPU usage
                std.time.sleep(1_000_000); // 1ms

                // Timeout for demo (60 seconds)
                if (message_count > 60_000) {
                    logger.info("Demo timeout (60s), exiting message loop", .{});
                    running = false;
                }
            }

            logger.info("Message loop ended after {d} iterations", .{message_count});
        } else {
            logger.err("No Dispatcher available!", .{});
            return @bitCast(winrt.E_FAIL);
        }

        logger.info("FrameworkView.Run completed successfully", .{});
        return winrt.S_OK;
    }

    fn uninitialize(
        iface: *view_interfaces.IFrameworkView,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        const self = getSelf(iface);

        logger.info("FrameworkView.Uninitialize called", .{});

        // Clean up resources
        if (self.dispatcher) |d| {
            _ = d.release();
            self.dispatcher = null;
        }

        if (self.core_window) |w| {
            _ = w.release();
            self.core_window = null;
        }

        if (self.app_view) |v| {
            _ = v.release();
            self.app_view = null;
        }

        logger.info("FrameworkView uninitialized", .{});
        return winrt.S_OK;
    }
};
