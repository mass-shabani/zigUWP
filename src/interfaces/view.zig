// src/interfaces/view.zig
// Windows.ApplicationModel.Core.IFrameworkView interfaces
// Core interfaces for UWP view management

const std = @import("std");
const winrt = @import("../core/winrt_core.zig");
const com = @import("../core/com_base.zig");

// Forward declarations
pub const ICoreApplicationView = @import("application.zig").ICoreApplicationView;
pub const ICoreWindow = @import("window.zig").ICoreWindow;

// ============================================================================
// Interface IDs
// ============================================================================

// IFrameworkViewSource: {CD770614-65C4-426C-9494-34FC43554662}
pub const IID_IFrameworkViewSource = winrt.GUID{
    .Data1 = 0xCD770614,
    .Data2 = 0x65C4,
    .Data3 = 0x426C,
    .Data4 = .{ 0x94, 0x94, 0x34, 0xFC, 0x43, 0x55, 0x46, 0x62 },
};

// IFrameworkView: {FAAB5CD0-506E-4CFF-8019-54F69A16F2D7}
pub const IID_IFrameworkView = winrt.GUID{
    .Data1 = 0xFAAB5CD0,
    .Data2 = 0x506E,
    .Data3 = 0x4CFF,
    .Data4 = .{ 0x80, 0x19, 0x54, 0xF6, 0x9A, 0x16, 0xF2, 0xD7 },
};

// ============================================================================
// IFrameworkViewSource
// ============================================================================

pub const IFrameworkViewSource = extern struct {
    vtbl: *const VTable,

    pub const VTable = extern struct {
        // IInspectable
        QueryInterface: *const fn (
            *IFrameworkViewSource,
            *const winrt.GUID,
            *?*anyopaque,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        AddRef: *const fn (
            *IFrameworkViewSource,
        ) callconv(winrt.WINAPI) u32,

        Release: *const fn (
            *IFrameworkViewSource,
        ) callconv(winrt.WINAPI) u32,

        GetIids: *const fn (
            *IFrameworkViewSource,
            *u32,
            *?[*]winrt.GUID,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetRuntimeClassName: *const fn (
            *IFrameworkViewSource,
            *winrt.HSTRING,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetTrustLevel: *const fn (
            *IFrameworkViewSource,
            *winrt.TrustLevel,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        // IFrameworkViewSource method
        CreateView: *const fn (
            *IFrameworkViewSource,
            *?*IFrameworkView,
        ) callconv(winrt.WINAPI) winrt.HRESULT,
    };

    // Helper methods
    pub inline fn queryInterface(
        self: *IFrameworkViewSource,
        riid: *const winrt.GUID,
        ppv: *?*anyopaque,
    ) winrt.HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppv);
    }

    pub inline fn addRef(self: *IFrameworkViewSource) u32 {
        return self.vtbl.AddRef(self);
    }

    pub inline fn release(self: *IFrameworkViewSource) u32 {
        return self.vtbl.Release(self);
    }

    pub inline fn createView(
        self: *IFrameworkViewSource,
        out: *?*IFrameworkView,
    ) winrt.HRESULT {
        return self.vtbl.CreateView(self, out);
    }
};

// ============================================================================
// IFrameworkView
// ============================================================================

pub const IFrameworkView = extern struct {
    vtbl: *const VTable,

    pub const VTable = extern struct {
        // IInspectable
        QueryInterface: *const fn (
            *IFrameworkView,
            *const winrt.GUID,
            *?*anyopaque,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        AddRef: *const fn (
            *IFrameworkView,
        ) callconv(winrt.WINAPI) u32,

        Release: *const fn (
            *IFrameworkView,
        ) callconv(winrt.WINAPI) u32,

        GetIids: *const fn (
            *IFrameworkView,
            *u32,
            *?[*]winrt.GUID,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetRuntimeClassName: *const fn (
            *IFrameworkView,
            *winrt.HSTRING,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetTrustLevel: *const fn (
            *IFrameworkView,
            *winrt.TrustLevel,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        // IFrameworkView methods
        Initialize: *const fn (
            *IFrameworkView,
            *ICoreApplicationView,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        SetWindow: *const fn (
            *IFrameworkView,
            *ICoreWindow,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        Load: *const fn (
            *IFrameworkView,
            winrt.HSTRING,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        Run: *const fn (
            *IFrameworkView,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        Uninitialize: *const fn (
            *IFrameworkView,
        ) callconv(winrt.WINAPI) winrt.HRESULT,
    };

    // Helper methods
    pub inline fn queryInterface(
        self: *IFrameworkView,
        riid: *const winrt.GUID,
        ppv: *?*anyopaque,
    ) winrt.HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppv);
    }

    pub inline fn addRef(self: *IFrameworkView) u32 {
        return self.vtbl.AddRef(self);
    }

    pub inline fn release(self: *IFrameworkView) u32 {
        return self.vtbl.Release(self);
    }

    pub inline fn initialize(
        self: *IFrameworkView,
        applicationView: *ICoreApplicationView,
    ) winrt.HRESULT {
        return self.vtbl.Initialize(self, applicationView);
    }

    pub inline fn setWindow(
        self: *IFrameworkView,
        window: *ICoreWindow,
    ) winrt.HRESULT {
        return self.vtbl.SetWindow(self, window);
    }

    pub inline fn load(
        self: *IFrameworkView,
        entryPoint: winrt.HSTRING,
    ) winrt.HRESULT {
        return self.vtbl.Load(self, entryPoint);
    }

    pub inline fn run(self: *IFrameworkView) winrt.HRESULT {
        return self.vtbl.Run(self);
    }

    pub inline fn uninitialize(self: *IFrameworkView) winrt.HRESULT {
        return self.vtbl.Uninitialize(self);
    }
};
