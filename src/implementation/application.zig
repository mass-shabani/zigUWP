// src/interfaces/application.zig
// Windows.ApplicationModel.Core interfaces
// ICoreApplication and ICoreApplicationView

const std = @import("std");
const winrt = @import("../core/winrt_core.zig");
const com = @import("../core/com_base.zig");
const view = @import("view.zig");
const window = @import("window.zig");

// ============================================================================
// Interface IDs
// ============================================================================

// ICoreApplication: {0AACF7A4-5E1D-49DF-8034-FB6A68BC5ED1}
pub const IID_ICoreApplication = winrt.GUID{
    .Data1 = 0x0AACF7A4,
    .Data2 = 0x5E1D,
    .Data3 = 0x49DF,
    .Data4 = .{ 0x80, 0x34, 0xFB, 0x6A, 0x68, 0xBC, 0x5E, 0xD1 },
};

// ICoreApplicationView: {638BB2DB-451D-4661-B099-414F34FFB9F1}
pub const IID_ICoreApplicationView = winrt.GUID{
    .Data1 = 0x638BB2DB,
    .Data2 = 0x451D,
    .Data3 = 0x4661,
    .Data4 = .{ 0xB0, 0x99, 0x41, 0x4F, 0x34, 0xFF, 0xB9, 0xF1 },
};

// ============================================================================
// ICoreApplication
// ============================================================================

pub const ICoreApplication = extern struct {
    vtbl: *const VTable,

    pub const VTable = extern struct {
        // IInspectable
        QueryInterface: *const fn (
            *ICoreApplication,
            *const winrt.GUID,
            *?*anyopaque,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        AddRef: *const fn (
            *ICoreApplication,
        ) callconv(winrt.WINAPI) u32,

        Release: *const fn (
            *ICoreApplication,
        ) callconv(winrt.WINAPI) u32,

        GetIids: *const fn (
            *ICoreApplication,
            *u32,
            *?[*]winrt.GUID,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetRuntimeClassName: *const fn (
            *ICoreApplication,
            *winrt.HSTRING,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetTrustLevel: *const fn (
            *ICoreApplication,
            *winrt.TrustLevel,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        // ICoreApplication methods
        get_Id: *const fn (
            *ICoreApplication,
            *winrt.HSTRING,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        add_Suspending: *const fn (
            *ICoreApplication,
            ?*anyopaque,
            *winrt.EventRegistrationToken,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        remove_Suspending: *const fn (
            *ICoreApplication,
            winrt.EventRegistrationToken,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        add_Resuming: *const fn (
            *ICoreApplication,
            ?*anyopaque,
            *winrt.EventRegistrationToken,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        remove_Resuming: *const fn (
            *ICoreApplication,
            winrt.EventRegistrationToken,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        get_Properties: *const fn (
            *ICoreApplication,
            *?*anyopaque,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetCurrentView: *const fn (
            *ICoreApplication,
            *?*ICoreApplicationView,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        Run: *const fn (
            *ICoreApplication,
            *view.IFrameworkViewSource,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        RunWithActivationFactories: *const fn (
            *ICoreApplication,
            ?*anyopaque,
        ) callconv(winrt.WINAPI) winrt.HRESULT,
    };

    // Helper methods
    pub inline fn queryInterface(
        self: *ICoreApplication,
        riid: *const winrt.GUID,
        ppv: *?*anyopaque,
    ) winrt.HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppv);
    }

    pub inline fn addRef(self: *ICoreApplication) u32 {
        return self.vtbl.AddRef(self);
    }

    pub inline fn release(self: *ICoreApplication) u32 {
        return self.vtbl.Release(self);
    }

    pub inline fn run(
        self: *ICoreApplication,
        viewSource: *view.IFrameworkViewSource,
    ) winrt.HRESULT {
        return self.vtbl.Run(self, viewSource);
    }

    pub inline fn getCurrentView(
        self: *ICoreApplication,
        out: *?*ICoreApplicationView,
    ) winrt.HRESULT {
        return self.vtbl.GetCurrentView(self, out);
    }
};

// ============================================================================
// ICoreApplicationView
// ============================================================================

pub const ICoreApplicationView = extern struct {
    vtbl: *const VTable,

    pub const VTable = extern struct {
        // IInspectable
        QueryInterface: *const fn (
            *ICoreApplicationView,
            *const winrt.GUID,
            *?*anyopaque,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        AddRef: *const fn (
            *ICoreApplicationView,
        ) callconv(winrt.WINAPI) u32,

        Release: *const fn (
            *ICoreApplicationView,
        ) callconv(winrt.WINAPI) u32,

        GetIids: *const fn (
            *ICoreApplicationView,
            *u32,
            *?[*]winrt.GUID,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetRuntimeClassName: *const fn (
            *ICoreApplicationView,
            *winrt.HSTRING,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetTrustLevel: *const fn (
            *ICoreApplicationView,
            *winrt.TrustLevel,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        // ICoreApplicationView methods
        get_CoreWindow: *const fn (
            *ICoreApplicationView,
            *?*window.ICoreWindow,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        add_Activated: *const fn (
            *ICoreApplicationView,
            ?*anyopaque,
            *winrt.EventRegistrationToken,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        remove_Activated: *const fn (
            *ICoreApplicationView,
            winrt.EventRegistrationToken,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        get_IsMain: *const fn (
            *ICoreApplicationView,
            *bool,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        get_IsHosted: *const fn (
            *ICoreApplicationView,
            *bool,
        ) callconv(winrt.WINAPI) winrt.HRESULT,
    };

    // Helper methods
    pub inline fn queryInterface(
        self: *ICoreApplicationView,
        riid: *const winrt.GUID,
        ppv: *?*anyopaque,
    ) winrt.HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppv);
    }

    pub inline fn addRef(self: *ICoreApplicationView) u32 {
        return self.vtbl.AddRef(self);
    }

    pub inline fn release(self: *ICoreApplicationView) u32 {
        return self.vtbl.Release(self);
    }

    pub inline fn getCoreWindow(
        self: *ICoreApplicationView,
        out: *?*window.ICoreWindow,
    ) winrt.HRESULT {
        return self.vtbl.get_CoreWindow(self, out);
    }
};
