const std = @import("std");
const winrt_core = @import("../core/winrt_core.zig");
const com_base = @import("../core/com_base.zig");
const windows = std.os.windows;

const WINAPI = winrt_core.WINAPI;
const HRESULT = winrt_core.HRESULT;
const GUID = winrt_core.GUID;
const HSTRING = winrt_core.HSTRING;
const TrustLevel = winrt_core.TrustLevel;
const EventRegistrationToken = winrt_core.EventRegistrationToken;
const CoreDispatcherPriority = winrt_core.CoreDispatcherPriority;
const CoreProcessEventsOption = winrt_core.CoreProcessEventsOption;

// Window-related GUIDs
pub const IID_ICoreWindow = GUID{
    .Data1 = 0x79B9D5F2,
    .Data2 = 0x879E,
    .Data3 = 0x4B89,
    .Data4 = .{ 0xB7, 0x98, 0x79, 0xE4, 0x75, 0x98, 0x03, 0x0C },
};

pub const IID_ICoreDispatcher = GUID{
    .Data1 = 0x60DB2FA8,
    .Data2 = 0xB705,
    .Data3 = 0x4FDE,
    .Data4 = .{ 0xA7, 0xD6, 0xEB, 0xBB, 0x17, 0x91, 0xF8, 0xC1 },
};

// ICoreWindow interface
pub const ICoreWindow = extern struct {
    vtbl: *const ICoreWindowVtbl,

    pub const ICoreWindowVtbl = extern struct {
        // IUnknown methods
        QueryInterface: *const fn (*ICoreWindow, *const GUID, *?*anyopaque) callconv(WINAPI) HRESULT,

        AddRef: *const fn (*ICoreWindow) callconv(WINAPI) u32,
        Release: *const fn (*ICoreWindow) callconv(WINAPI) u32,

        // IInspectable methods
        GetIids: *const fn (*ICoreWindow, *u32, *?**GUID) callconv(WINAPI) HRESULT,

        GetRuntimeClassName: *const fn (*ICoreWindow, *HSTRING) callconv(WINAPI) HRESULT,

        GetTrustLevel: *const fn (*ICoreWindow, *TrustLevel) callconv(WINAPI) HRESULT,

        // ICoreWindow methods
        get_AutomationHostProvider: *const fn (*ICoreWindow, *?*anyopaque) callconv(WINAPI) HRESULT,

        get_Bounds: *const fn (*ICoreWindow, *windows.RECT) callconv(WINAPI) HRESULT,

        get_CustomProperties: *const fn (*ICoreWindow, *?*anyopaque) callconv(WINAPI) HRESULT,

        get_Dispatcher: *const fn (*ICoreWindow, *?*ICoreDispatcher) callconv(WINAPI) HRESULT,

        get_FlowDirection: *const fn (*ICoreWindow, *u32) callconv(WINAPI) HRESULT,

        put_FlowDirection: *const fn (*ICoreWindow, u32) callconv(WINAPI) HRESULT,

        get_IsInputEnabled: *const fn (*ICoreWindow, *bool) callconv(WINAPI) HRESULT,

        put_IsInputEnabled: *const fn (*ICoreWindow, bool) callconv(WINAPI) HRESULT,

        get_PointerCursor: *const fn (*ICoreWindow, *?*anyopaque) callconv(WINAPI) HRESULT,

        put_PointerCursor: *const fn (*ICoreWindow, ?*anyopaque) callconv(WINAPI) HRESULT,

        get_PointerPosition: *const fn (*ICoreWindow, *windows.POINT) callconv(WINAPI) HRESULT,

        get_Visible: *const fn (*ICoreWindow, *bool) callconv(WINAPI) HRESULT,

        Activate: *const fn (*ICoreWindow) callconv(WINAPI) HRESULT,
        Close: *const fn (*ICoreWindow) callconv(WINAPI) HRESULT,

        GetAsyncKeyState: *const fn (*ICoreWindow, u32, *u32) callconv(WINAPI) HRESULT,

        GetKeyState: *const fn (*ICoreWindow, u32, *u32) callconv(WINAPI) HRESULT,

        ReleasePointerCapture: *const fn (*ICoreWindow) callconv(WINAPI) HRESULT,
        SetPointerCapture: *const fn (*ICoreWindow) callconv(WINAPI) HRESULT,

        // Event handlers
        add_Activated: *const fn (*ICoreWindow, ?*anyopaque, *EventRegistrationToken) callconv(WINAPI) HRESULT,

        remove_Activated: *const fn (*ICoreWindow, EventRegistrationToken) callconv(WINAPI) HRESULT,

        add_Closed: *const fn (*ICoreWindow, ?*anyopaque, *EventRegistrationToken) callconv(WINAPI) HRESULT,

        remove_Closed: *const fn (*ICoreWindow, EventRegistrationToken) callconv(WINAPI) HRESULT,

        add_SizeChanged: *const fn (*ICoreWindow, ?*anyopaque, *EventRegistrationToken) callconv(WINAPI) HRESULT,

        remove_SizeChanged: *const fn (*ICoreWindow, EventRegistrationToken) callconv(WINAPI) HRESULT,

        add_VisibilityChanged: *const fn (*ICoreWindow, ?*anyopaque, *EventRegistrationToken) callconv(WINAPI) HRESULT,

        remove_VisibilityChanged: *const fn (*ICoreWindow, EventRegistrationToken) callconv(WINAPI) HRESULT,
    };

    // Helper methods
    pub fn queryInterface(self: *ICoreWindow, riid: *const GUID, ppvObject: *?*anyopaque) HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppvObject);
    }

    pub fn addRef(self: *ICoreWindow) u32 {
        return self.vtbl.AddRef(self);
    }

    pub fn release(self: *ICoreWindow) u32 {
        return self.vtbl.Release(self);
    }

    pub fn activate(self: *ICoreWindow) HRESULT {
        return self.vtbl.Activate(self);
    }

    pub fn getDispatcher(self: *ICoreWindow, dispatcher: *?*ICoreDispatcher) HRESULT {
        return self.vtbl.get_Dispatcher(self, dispatcher);
    }

    pub fn getVisible(self: *ICoreWindow, visible: *bool) HRESULT {
        return self.vtbl.get_Visible(self, visible);
    }

    pub fn getBounds(self: *ICoreWindow, bounds: *windows.RECT) HRESULT {
        return self.vtbl.get_Bounds(self, bounds);
    }
};

// ICoreDispatcher interface
pub const ICoreDispatcher = extern struct {
    vtbl: *const ICoreDispatcherVtbl,

    pub const ICoreDispatcherVtbl = extern struct {
        // IUnknown methods
        QueryInterface: *const fn (*ICoreDispatcher, *const GUID, *?*anyopaque) callconv(WINAPI) HRESULT,

        AddRef: *const fn (*ICoreDispatcher) callconv(WINAPI) u32,
        Release: *const fn (*ICoreDispatcher) callconv(WINAPI) u32,

        // IInspectable methods
        GetIids: *const fn (*ICoreDispatcher, *u32, *?**GUID) callconv(WINAPI) HRESULT,

        GetRuntimeClassName: *const fn (*ICoreDispatcher, *HSTRING) callconv(WINAPI) HRESULT,

        GetTrustLevel: *const fn (*ICoreDispatcher, *TrustLevel) callconv(WINAPI) HRESULT,

        // ICoreDispatcher methods
        get_HasThreadAccess: *const fn (*ICoreDispatcher, *bool) callconv(WINAPI) HRESULT,

        ProcessEvents: *const fn (*ICoreDispatcher, u32) callconv(WINAPI) HRESULT,

        RunAsync: *const fn (*ICoreDispatcher, CoreDispatcherPriority, ?*anyopaque, *?*anyopaque) callconv(WINAPI) HRESULT,

        RunIdleAsync: *const fn (*ICoreDispatcher, ?*anyopaque, *?*anyopaque) callconv(WINAPI) HRESULT,
    };

    // Helper methods
    pub fn queryInterface(self: *ICoreDispatcher, riid: *const GUID, ppvObject: *?*anyopaque) HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppvObject);
    }

    pub fn addRef(self: *ICoreDispatcher) u32 {
        return self.vtbl.AddRef(self);
    }

    pub fn release(self: *ICoreDispatcher) u32 {
        return self.vtbl.Release(self);
    }

    pub fn processEvents(self: *ICoreDispatcher, options: CoreProcessEventsOption) HRESULT {
        return self.vtbl.ProcessEvents(self, @intFromEnum(options));
    }

    pub fn hasThreadAccess(self: *ICoreDispatcher, has_access: *bool) HRESULT {
        return self.vtbl.get_HasThreadAccess(self, has_access);
    }
};

// Window manager for handling window lifecycle
pub const WindowManager = struct {
    allocator: std.mem.Allocator,
    core_window: ?*ICoreWindow,
    dispatcher: ?*ICoreDispatcher,
    is_activated: bool,
    is_visible: bool,
    bounds: windows.RECT,

    pub fn init(allocator: std.mem.Allocator) WindowManager {
        return WindowManager{
            .allocator = allocator,
            .core_window = null,
            .dispatcher = null,
            .is_activated = false,
            .is_visible = false,
            .bounds = std.mem.zeroes(windows.RECT),
        };
    }

    pub fn deinit(self: *WindowManager) void {
        if (self.dispatcher) |dispatcher| {
            _ = dispatcher.release();
            self.dispatcher = null;
        }

        if (self.core_window) |window| {
            _ = window.release();
            self.core_window = null;
        }
    }

    pub fn setWindow(self: *WindowManager, window: *ICoreWindow) !void {
        if (self.core_window) |old_window| {
            _ = old_window.release();
        }

        self.core_window = window;
        _ = window.addRef();

        // Get the dispatcher
        var dispatcher: ?*ICoreDispatcher = null;
        const hr = window.getDispatcher(&dispatcher);
        if (winrt_core.isSuccess(hr) and dispatcher != null) {
            self.dispatcher = dispatcher;
        }

        // Update window state
        try self.updateWindowState();
    }

    pub fn activateWindow(self: *WindowManager) !void {
        if (self.core_window) |window| {
            const hr = window.activate();
            if (winrt_core.isFailure(hr)) {
                std.debug.print("Failed to activate window. HRESULT: 0x{X}\n", .{hr});
                return winrt_core.hrToError(hr);
            }
            self.is_activated = true;
            std.debug.print("Window activated successfully\n", .{});
        } else {
            return error.NoWindow;
        }
    }

    pub fn updateWindowState(self: *WindowManager) !void {
        if (self.core_window) |window| {
            // Update visibility
            var visible: bool = false;
            _ = window.getVisible(&visible);
            self.is_visible = visible;

            // Update bounds
            _ = window.getBounds(&self.bounds);
        }
    }

    pub fn runMessageLoop(self: *WindowManager) !void {
        if (self.dispatcher) |dispatcher| {
            std.debug.print("Starting UWP message loop...\n", .{});

            var running = true;
            var iteration_count: u32 = 0;

            while (running) {
                // Process events
                const hr = dispatcher.processEvents(CoreProcessEventsOption.ProcessOneAndAllPending);

                if (winrt_core.isFailure(hr)) {
                    std.debug.print("ProcessEvents failed. HRESULT: 0x{X}\n", .{hr});
                    break;
                }

                // Update window state
                self.updateWindowState() catch {
                    std.debug.print("Failed to update window state\n", .{});
                };

                // Check if window is still visible
                if (!self.is_visible) {
                    std.debug.print("Window is no longer visible, exiting message loop\n", .{});
                    running = false;
                }

                iteration_count += 1;
                if (iteration_count % 1000 == 0) {
                    std.debug.print("Message loop iteration: {}\n", .{iteration_count});
                }

                // Timeout for demo (30 seconds)
                if (iteration_count > 30000) {
                    std.debug.print("Demo timeout reached, exiting message loop\n", .{});
                    running = false;
                }

                // Small delay to prevent 100% CPU usage
                std.time.sleep(1_000_000); // 1ms
            }

            std.debug.print("Message loop ended after {} iterations\n", .{iteration_count});
        } else {
            return error.NoDispatcher;
        }
    }

    pub fn getWindowInfo(self: *const WindowManager) struct {
        has_window: bool,
        has_dispatcher: bool,
        is_activated: bool,
        is_visible: bool,
        width: i32,
        height: i32,
    } {
        return .{
            .has_window = self.core_window != null,
            .has_dispatcher = self.dispatcher != null,
            .is_activated = self.is_activated,
            .is_visible = self.is_visible,
            .width = self.bounds.right - self.bounds.left,
            .height = self.bounds.bottom - self.bounds.top,
        };
    }
};
