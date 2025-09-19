const std = @import("std");
const winrt_core = @import("../core/winrt_core.zig");
const com_base = @import("../core/com_base.zig");
const window_interfaces = @import("window.zig");
const application_interfaces = @import("application.zig");

const WINAPI = winrt_core.WINAPI;
const HRESULT = winrt_core.HRESULT;
const GUID = winrt_core.GUID;
const HSTRING = winrt_core.HSTRING;
const TrustLevel = winrt_core.TrustLevel;

// Framework View GUIDs
pub const IID_IFrameworkViewSource = GUID{
    .Data1 = 0xCD770614,
    .Data2 = 0x65C4,
    .Data3 = 0x426C,
    .Data4 = .{ 0x94, 0x94, 0x34, 0xFC, 0x43, 0x55, 0x46, 0x62 },
};

pub const IID_IFrameworkView = GUID{
    .Data1 = 0xFAAB5CD0,
    .Data2 = 0x506E,
    .Data3 = 0x4CFF,
    .Data4 = .{ 0x80, 0x19, 0x54, 0xF6, 0x9A, 0x16, 0xF2, 0xD7 },
};

// IFrameworkViewSource interface
pub const IFrameworkViewSource = extern struct {
    vtbl: *const IFrameworkViewSourceVtbl,

    pub const IFrameworkViewSourceVtbl = extern struct {
        // IUnknown methods
        QueryInterface: *const fn (*IFrameworkViewSource, *const GUID, *?*anyopaque) callconv(WINAPI) HRESULT,

        AddRef: *const fn (*IFrameworkViewSource) callconv(WINAPI) u32,
        Release: *const fn (*IFrameworkViewSource) callconv(WINAPI) u32,

        // IInspectable methods
        GetIids: *const fn (*IFrameworkViewSource, *u32, *?**GUID) callconv(WINAPI) HRESULT,

        GetRuntimeClassName: *const fn (*IFrameworkViewSource, *HSTRING) callconv(WINAPI) HRESULT,

        GetTrustLevel: *const fn (*IFrameworkViewSource, *TrustLevel) callconv(WINAPI) HRESULT,

        // IFrameworkViewSource methods
        CreateView: *const fn (*IFrameworkViewSource, *?*IFrameworkView) callconv(WINAPI) HRESULT,
    };

    // Helper methods
    pub fn queryInterface(self: *IFrameworkViewSource, riid: *const GUID, ppvObject: *?*anyopaque) HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppvObject);
    }

    pub fn addRef(self: *IFrameworkViewSource) u32 {
        return self.vtbl.AddRef(self);
    }

    pub fn release(self: *IFrameworkViewSource) u32 {
        return self.vtbl.Release(self);
    }

    pub fn createView(self: *IFrameworkViewSource, view: *?*IFrameworkView) HRESULT {
        return self.vtbl.CreateView(self, view);
    }
};

// IFrameworkView interface
pub const IFrameworkView = extern struct {
    vtbl: *const IFrameworkViewVtbl,

    pub const IFrameworkViewVtbl = extern struct {
        // IUnknown methods
        QueryInterface: *const fn (*IFrameworkView, *const GUID, *?*anyopaque) callconv(WINAPI) HRESULT,

        AddRef: *const fn (*IFrameworkView) callconv(WINAPI) u32,
        Release: *const fn (*IFrameworkView) callconv(WINAPI) u32,

        // IInspectable methods
        GetIids: *const fn (*IFrameworkView, *u32, *?**GUID) callconv(WINAPI) HRESULT,

        GetRuntimeClassName: *const fn (*IFrameworkView, *HSTRING) callconv(WINAPI) HRESULT,

        GetTrustLevel: *const fn (*IFrameworkView, *TrustLevel) callconv(WINAPI) HRESULT,

        // IFrameworkView methods
        Initialize: *const fn (*IFrameworkView, *application_interfaces.ICoreApplicationView) callconv(WINAPI) HRESULT,

        SetWindow: *const fn (*IFrameworkView, *window_interfaces.ICoreWindow) callconv(WINAPI) HRESULT,

        Load: *const fn (*IFrameworkView, HSTRING) callconv(WINAPI) HRESULT,

        Run: *const fn (*IFrameworkView) callconv(WINAPI) HRESULT,

        Uninitialize: *const fn (*IFrameworkView) callconv(WINAPI) HRESULT,
    };

    // Helper methods
    pub fn queryInterface(self: *IFrameworkView, riid: *const GUID, ppvObject: *?*anyopaque) HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppvObject);
    }

    pub fn addRef(self: *IFrameworkView) u32 {
        return self.vtbl.AddRef(self);
    }

    pub fn release(self: *IFrameworkView) u32 {
        return self.vtbl.Release(self);
    }

    pub fn initialize(self: *IFrameworkView, app_view: *application_interfaces.ICoreApplicationView) HRESULT {
        return self.vtbl.Initialize(self, app_view);
    }

    pub fn setWindow(self: *IFrameworkView, window: *window_interfaces.ICoreWindow) HRESULT {
        return self.vtbl.SetWindow(self, window);
    }

    pub fn load(self: *IFrameworkView, entryPoint: HSTRING) HRESULT {
        return self.vtbl.Load(self, entryPoint);
    }

    pub fn run(self: *IFrameworkView) HRESULT {
        return self.vtbl.Run(self);
    }

    pub fn uninitialize(self: *IFrameworkView) HRESULT {
        return self.vtbl.Uninitialize(self);
    }
};

// View lifecycle manager
pub const ViewLifecycleManager = struct {
    allocator: std.mem.Allocator,
    current_view: ?*IFrameworkView,
    current_window: ?*window_interfaces.ICoreWindow,
    is_initialized: bool,
    is_loaded: bool,
    is_running: bool,

    pub fn init(allocator: std.mem.Allocator) ViewLifecycleManager {
        return ViewLifecycleManager{
            .allocator = allocator,
            .current_view = null,
            .current_window = null,
            .is_initialized = false,
            .is_loaded = false,
            .is_running = false,
        };
    }

    pub fn deinit(self: *ViewLifecycleManager) void {
        self.shutdown();
    }

    pub fn setView(self: *ViewLifecycleManager, view: *IFrameworkView) void {
        if (self.current_view) |old_view| {
            _ = old_view.release();
        }

        self.current_view = view;
        _ = view.addRef();
    }

    pub fn setWindow(self: *ViewLifecycleManager, window: *window_interfaces.ICoreWindow) void {
        if (self.current_window) |old_window| {
            _ = old_window.release();
        }

        self.current_window = window;
        _ = window.addRef();
    }

    pub fn shutdown(self: *ViewLifecycleManager) void {
        if (self.current_view) |view| {
            if (self.is_running) {
                // Note: In real UWP, we would call uninitialize, but
                // since we're managing lifecycle manually, we just release
                _ = view.release();
                self.is_running = false;
            }
            self.current_view = null;
        }

        if (self.current_window) |window| {
            _ = window.release();
            self.current_window = null;
        }

        self.is_initialized = false;
        self.is_loaded = false;
    }

    pub fn getState(self: *const ViewLifecycleManager) struct {
        initialized: bool,
        loaded: bool,
        running: bool,
        has_view: bool,
        has_window: bool,
    } {
        return .{
            .initialized = self.is_initialized,
            .loaded = self.is_loaded,
            .running = self.is_running,
            .has_view = self.current_view != null,
            .has_window = self.current_window != null,
        };
    }
};
