const std = @import("std");
const winrt_core = @import("../core/winrt_core.zig");
const com_base = @import("../core/com_base.zig");
const view_interfaces = @import("view.zig");

const WINAPI = winrt_core.WINAPI;
const HRESULT = winrt_core.HRESULT;
const GUID = winrt_core.GUID;
const HSTRING = winrt_core.HSTRING;
const TrustLevel = winrt_core.TrustLevel;
const EventRegistrationToken = winrt_core.EventRegistrationToken;
const ApplicationExecutionState = winrt_core.ApplicationExecutionState;

// Core Application GUIDs
pub const IID_ICoreApplication = GUID{
    .Data1 = 0x0AACF7A4,
    .Data2 = 0x5E1D,
    .Data3 = 0x49DF,
    .Data4 = .{ 0x80, 0x34, 0xFB, 0x6A, 0x68, 0xBC, 0x5E, 0xD1 },
};

pub const IID_ICoreApplicationView = GUID{
    .Data1 = 0x638BB2DB,
    .Data2 = 0x451D,
    .Data3 = 0x4661,
    .Data4 = .{ 0xB0, 0x99, 0x41, 0x4F, 0x34, 0xFF, 0xB9, 0xF1 },
};

// ICoreApplication interface
pub const ICoreApplication = extern struct {
    vtbl: *const ICoreApplicationVtbl,

    pub const ICoreApplicationVtbl = extern struct {
        // IUnknown methods
        QueryInterface: *const fn (*ICoreApplication, *const GUID, *?*anyopaque) callconv(WINAPI) HRESULT,

        AddRef: *const fn (*ICoreApplication) callconv(WINAPI) u32,
        Release: *const fn (*ICoreApplication) callconv(WINAPI) u32,

        // IInspectable methods
        GetIids: *const fn (*ICoreApplication, *u32, *?**GUID) callconv(WINAPI) HRESULT,

        GetRuntimeClassName: *const fn (*ICoreApplication, *HSTRING) callconv(WINAPI) HRESULT,

        GetTrustLevel: *const fn (*ICoreApplication, *TrustLevel) callconv(WINAPI) HRESULT,

        // ICoreApplication methods
        get_Id: *const fn (*ICoreApplication, *HSTRING) callconv(WINAPI) HRESULT,

        add_Suspending: *const fn (*ICoreApplication, ?*anyopaque, *EventRegistrationToken) callconv(WINAPI) HRESULT,

        remove_Suspending: *const fn (*ICoreApplication, EventRegistrationToken) callconv(WINAPI) HRESULT,

        add_Resuming: *const fn (*ICoreApplication, ?*anyopaque, *EventRegistrationToken) callconv(WINAPI) HRESULT,

        remove_Resuming: *const fn (*ICoreApplication, EventRegistrationToken) callconv(WINAPI) HRESULT,

        get_Properties: *const fn (*ICoreApplication, *?*anyopaque) callconv(WINAPI) HRESULT,

        GetCurrentView: *const fn (*ICoreApplication, *?*ICoreApplicationView) callconv(WINAPI) HRESULT,

        Run: *const fn (*ICoreApplication, *view_interfaces.IFrameworkViewSource) callconv(WINAPI) HRESULT,

        RunWithActivationFactories: *const fn (*ICoreApplication, ?*anyopaque) callconv(WINAPI) HRESULT,
    };

    // Helper methods
    pub fn queryInterface(self: *ICoreApplication, riid: *const GUID, ppvObject: *?*anyopaque) HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppvObject);
    }

    pub fn addRef(self: *ICoreApplication) u32 {
        return self.vtbl.AddRef(self);
    }

    pub fn release(self: *ICoreApplication) u32 {
        return self.vtbl.Release(self);
    }

    pub fn run(self: *ICoreApplication, view_source: *view_interfaces.IFrameworkViewSource) HRESULT {
        return self.vtbl.Run(self, view_source);
    }

    pub fn getCurrentView(self: *ICoreApplication, view: *?*ICoreApplicationView) HRESULT {
        return self.vtbl.GetCurrentView(self, view);
    }
};

// ICoreApplicationView interface
pub const ICoreApplicationView = extern struct {
    vtbl: *const ICoreApplicationViewVtbl,

    pub const ICoreApplicationViewVtbl = extern struct {
        // IUnknown methods
        QueryInterface: *const fn (*ICoreApplicationView, *const GUID, *?*anyopaque) callconv(WINAPI) HRESULT,

        AddRef: *const fn (*ICoreApplicationView) callconv(WINAPI) u32,
        Release: *const fn (*ICoreApplicationView) callconv(WINAPI) u32,

        // IInspectable methods
        GetIids: *const fn (*ICoreApplicationView, *u32, *?**GUID) callconv(WINAPI) HRESULT,

        GetRuntimeClassName: *const fn (*ICoreApplicationView, *HSTRING) callconv(WINAPI) HRESULT,

        GetTrustLevel: *const fn (*ICoreApplicationView, *TrustLevel) callconv(WINAPI) HRESULT,

        // ICoreApplicationView methods
        get_CoreWindow: *const fn (*ICoreApplicationView, *?*@import("window.zig").ICoreWindow) callconv(WINAPI) HRESULT,

        add_Activated: *const fn (*ICoreApplicationView, ?*anyopaque, *EventRegistrationToken) callconv(WINAPI) HRESULT,

        remove_Activated: *const fn (*ICoreApplicationView, EventRegistrationToken) callconv(WINAPI) HRESULT,

        get_IsMain: *const fn (*ICoreApplicationView, *bool) callconv(WINAPI) HRESULT,
        get_IsHosted: *const fn (*ICoreApplicationView, *bool) callconv(WINAPI) HRESULT,
    };

    // Helper methods
    pub fn queryInterface(self: *ICoreApplicationView, riid: *const GUID, ppvObject: *?*anyopaque) HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppvObject);
    }

    pub fn addRef(self: *ICoreApplicationView) u32 {
        return self.vtbl.AddRef(self);
    }

    pub fn release(self: *ICoreApplicationView) u32 {
        return self.vtbl.Release(self);
    }

    pub fn getCoreWindow(self: *ICoreApplicationView, window: *?*@import("window.zig").ICoreWindow) HRESULT {
        return self.vtbl.get_CoreWindow(self, window);
    }
};

// Application manager to handle core application lifecycle
pub const CoreApplicationManager = struct {
    allocator: std.mem.Allocator,
    core_application: ?*ICoreApplication,

    pub fn init(allocator: std.mem.Allocator) CoreApplicationManager {
        return CoreApplicationManager{
            .allocator = allocator,
            .core_application = null,
        };
    }

    pub fn deinit(self: *CoreApplicationManager) void {
        if (self.core_application) |app| {
            _ = app.release();
            self.core_application = null;
        }
    }

    pub fn getCoreApplication(self: *CoreApplicationManager) !*ICoreApplication {
        if (self.core_application) |app| {
            _ = app.addRef();
            return app;
        }

        // Get the CoreApplication singleton
        const activation = @import("../core/activation.zig");
        var factory_manager = activation.ActivationFactoryManager.init(self.allocator);

        const factory_ptr = try factory_manager.getActivationFactory("Windows.ApplicationModel.Core.CoreApplication", &IID_ICoreApplication);

        self.core_application = @alignCast(@ptrCast(factory_ptr));
        _ = self.core_application.?.addRef();

        return self.core_application.?;
    }
};
