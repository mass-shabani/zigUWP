// src/interfaces/window.zig
// Windows.UI.Core.ICoreWindow interface
// Minimal implementation for window management

const std = @import("std");
const winrt = @import("../core/winrt_core.zig");
const com = @import("../core/com_base.zig");

// ============================================================================
// Interface IDs
// ============================================================================

// ICoreWindow: {79B9D5F2-879E-4B89-B798-79E47598030C}
pub const IID_ICoreWindow = winrt.GUID{
    .Data1 = 0x79B9D5F2,
    .Data2 = 0x879E,
    .Data3 = 0x4B89,
    .Data4 = .{ 0xB7, 0x98, 0x79, 0xE4, 0x75, 0x98, 0x03, 0x0C },
};

// ICoreDispatcher: {60DB2FA8-B705-4FDE-A7D6-EBBB1791F8C1}
pub const IID_ICoreDispatcher = winrt.GUID{
    .Data1 = 0x60DB2FA8,
    .Data2 = 0xB705,
    .Data3 = 0x4FDE,
    .Data4 = .{ 0xA7, 0xD6, 0xEB, 0xBB, 0x17, 0x91, 0xF8, 0xC1 },
};

// ============================================================================
// ICoreWindow (simplified)
// ============================================================================

pub const ICoreWindow = extern struct {
    vtbl: *const VTable,

    pub const VTable = extern struct {
        // IInspectable
        QueryInterface: *const fn (
            *ICoreWindow,
            *const winrt.GUID,
            *?*anyopaque,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        AddRef: *const fn (
            *ICoreWindow,
        ) callconv(winrt.WINAPI) u32,

        Release: *const fn (
            *ICoreWindow,
        ) callconv(winrt.WINAPI) u32,

        GetIids: *const fn (
            *ICoreWindow,
            *u32,
            *?[*]winrt.GUID,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetRuntimeClassName: *const fn (
            *ICoreWindow,
            *winrt.HSTRING,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetTrustLevel: *const fn (
            *ICoreWindow,
            *winrt.TrustLevel,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        // ICoreWindow methods (minimal set)
        get_AutomationHostProvider: *const fn (
            *ICoreWindow,
            *?*anyopaque,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        get_Bounds: *const fn (
            *ICoreWindow,
            *Rect,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        get_CustomProperties: *const fn (
            *ICoreWindow,
            *?*anyopaque,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        get_Dispatcher: *const fn (
            *ICoreWindow,
            *?*ICoreDispatcher,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        get_FlowDirection: *const fn (
            *ICoreWindow,
            *i32,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        put_FlowDirection: *const fn (
            *ICoreWindow,
            i32,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        get_IsInputEnabled: *const fn (
            *ICoreWindow,
            *bool,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        put_IsInputEnabled: *const fn (
            *ICoreWindow,
            bool,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        get_PointerCursor: *const fn (
            *ICoreWindow,
            *?*anyopaque,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        put_PointerCursor: *const fn (
            *ICoreWindow,
            ?*anyopaque,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        get_PointerPosition: *const fn (
            *ICoreWindow,
            *Point,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        get_Visible: *const fn (
            *ICoreWindow,
            *bool,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        Activate: *const fn (
            *ICoreWindow,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        Close: *const fn (
            *ICoreWindow,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetAsyncKeyState: *const fn (
            *ICoreWindow,
            i32,
            *i32,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetKeyState: *const fn (
            *ICoreWindow,
            i32,
            *i32,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        ReleasePointerCapture: *const fn (
            *ICoreWindow,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        SetPointerCapture: *const fn (
            *ICoreWindow,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        // Event handlers (we'll skip most for simplicity)
        add_Activated: *const fn (
            *ICoreWindow,
            ?*anyopaque,
            *winrt.EventRegistrationToken,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        remove_Activated: *const fn (
            *ICoreWindow,
            winrt.EventRegistrationToken,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        // ... (skipping many event handlers for brevity)
    };

    // Helper methods
    pub inline fn queryInterface(
        self: *ICoreWindow,
        riid: *const winrt.GUID,
        ppv: *?*anyopaque,
    ) winrt.HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppv);
    }

    pub inline fn addRef(self: *ICoreWindow) u32 {
        return self.vtbl.AddRef(self);
    }

    pub inline fn release(self: *ICoreWindow) u32 {
        return self.vtbl.Release(self);
    }

    pub inline fn activate(self: *ICoreWindow) winrt.HRESULT {
        return self.vtbl.Activate(self);
    }

    pub inline fn getDispatcher(
        self: *ICoreWindow,
        out: *?*ICoreDispatcher,
    ) winrt.HRESULT {
        return self.vtbl.get_Dispatcher(self, out);
    }

    pub inline fn getVisible(
        self: *ICoreWindow,
        out: *bool,
    ) winrt.HRESULT {
        return self.vtbl.get_Visible(self, out);
    }

    pub inline fn getBounds(
        self: *ICoreWindow,
        out: *Rect,
    ) winrt.HRESULT {
        return self.vtbl.get_Bounds(self, out);
    }
};

// ============================================================================
// ICoreDispatcher
// ============================================================================

pub const ICoreDispatcher = extern struct {
    vtbl: *const VTable,

    pub const VTable = extern struct {
        // IInspectable
        QueryInterface: *const fn (
            *ICoreDispatcher,
            *const winrt.GUID,
            *?*anyopaque,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        AddRef: *const fn (
            *ICoreDispatcher,
        ) callconv(winrt.WINAPI) u32,

        Release: *const fn (
            *ICoreDispatcher,
        ) callconv(winrt.WINAPI) u32,

        GetIids: *const fn (
            *ICoreDispatcher,
            *u32,
            *?[*]winrt.GUID,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetRuntimeClassName: *const fn (
            *ICoreDispatcher,
            *winrt.HSTRING,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetTrustLevel: *const fn (
            *ICoreDispatcher,
            *winrt.TrustLevel,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        // ICoreDispatcher methods
        get_HasThreadAccess: *const fn (
            *ICoreDispatcher,
            *bool,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        ProcessEvents: *const fn (
            *ICoreDispatcher,
            winrt.CoreProcessEventsOption,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        RunAsync: *const fn (
            *ICoreDispatcher,
            winrt.CoreDispatcherPriority,
            ?*anyopaque,
            *?*anyopaque,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        RunIdleAsync: *const fn (
            *ICoreDispatcher,
            ?*anyopaque,
            *?*anyopaque,
        ) callconv(winrt.WINAPI) winrt.HRESULT,
    };

    // Helper methods
    pub inline fn queryInterface(
        self: *ICoreDispatcher,
        riid: *const winrt.GUID,
        ppv: *?*anyopaque,
    ) winrt.HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppv);
    }

    pub inline fn addRef(self: *ICoreDispatcher) u32 {
        return self.vtbl.AddRef(self);
    }

    pub inline fn release(self: *ICoreDispatcher) u32 {
        return self.vtbl.Release(self);
    }

    pub inline fn processEvents(
        self: *ICoreDispatcher,
        option: winrt.CoreProcessEventsOption,
    ) winrt.HRESULT {
        return self.vtbl.ProcessEvents(self, option);
    }
};

// ============================================================================
// Helper Types
// ============================================================================

pub const Point = extern struct {
    x: f32,
    y: f32,
};

pub const Rect = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};
