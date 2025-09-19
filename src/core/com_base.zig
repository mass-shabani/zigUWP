const std = @import("std");
const winrt_core = @import("winrt_core.zig");
const WINAPI = winrt_core.WINAPI;
const HRESULT = winrt_core.HRESULT;
const GUID = winrt_core.GUID;
const HSTRING = winrt_core.HSTRING;
const TrustLevel = winrt_core.TrustLevel;

// Core COM/WinRT GUIDs
pub const IID_IUnknown = GUID{
    .Data1 = 0x00000000,
    .Data2 = 0x0000,
    .Data3 = 0x0000,
    .Data4 = .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 },
};

pub const IID_IInspectable = GUID{
    .Data1 = 0xAF86E2E0,
    .Data2 = 0xB12D,
    .Data3 = 0x4c6a,
    .Data4 = .{ 0x9C, 0x5A, 0xD7, 0xAA, 0x65, 0x10, 0x1E, 0x90 },
};

pub const IID_IActivationFactory = GUID{
    .Data1 = 0x00000035,
    .Data2 = 0x0000,
    .Data3 = 0x0000,
    .Data4 = .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 },
};

// Base COM interface - IUnknown
pub const IUnknown = extern struct {
    vtbl: *const IUnknownVtbl,

    pub const IUnknownVtbl = extern struct {
        QueryInterface: *const fn (*IUnknown, *const GUID, *?*anyopaque) callconv(WINAPI) HRESULT,

        AddRef: *const fn (*IUnknown) callconv(WINAPI) u32,
        Release: *const fn (*IUnknown) callconv(WINAPI) u32,
    };

    // Helper methods
    pub fn queryInterface(self: *IUnknown, riid: *const GUID, ppvObject: *?*anyopaque) HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppvObject);
    }

    pub fn addRef(self: *IUnknown) u32 {
        return self.vtbl.AddRef(self);
    }

    pub fn release(self: *IUnknown) u32 {
        return self.vtbl.Release(self);
    }
};

// WinRT base interface - IInspectable (inherits from IUnknown)
pub const IInspectable = extern struct {
    vtbl: *const IInspectableVtbl,

    pub const IInspectableVtbl = extern struct {
        // IUnknown methods
        QueryInterface: *const fn (*IInspectable, *const GUID, *?*anyopaque) callconv(WINAPI) HRESULT,

        AddRef: *const fn (*IInspectable) callconv(WINAPI) u32,
        Release: *const fn (*IInspectable) callconv(WINAPI) u32,

        // IInspectable methods
        GetIids: *const fn (*IInspectable, *u32, *?**GUID) callconv(WINAPI) HRESULT,

        GetRuntimeClassName: *const fn (*IInspectable, *HSTRING) callconv(WINAPI) HRESULT,

        GetTrustLevel: *const fn (*IInspectable, *TrustLevel) callconv(WINAPI) HRESULT,
    };

    // Helper methods for IUnknown
    pub fn queryInterface(self: *IInspectable, riid: *const GUID, ppvObject: *?*anyopaque) HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppvObject);
    }

    pub fn addRef(self: *IInspectable) u32 {
        return self.vtbl.AddRef(self);
    }

    pub fn release(self: *IInspectable) u32 {
        return self.vtbl.Release(self);
    }

    // Helper methods for IInspectable
    pub fn getIids(self: *IInspectable, iidCount: *u32, iids: *?**GUID) HRESULT {
        return self.vtbl.GetIids(self, iidCount, iids);
    }

    pub fn getRuntimeClassName(self: *IInspectable, className: *HSTRING) HRESULT {
        return self.vtbl.GetRuntimeClassName(self, className);
    }

    pub fn getTrustLevel(self: *IInspectable, trustLevel: *TrustLevel) HRESULT {
        return self.vtbl.GetTrustLevel(self, trustLevel);
    }
};

// Base COM object implementation helper
pub const ComObjectBase = struct {
    ref_count: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ComObjectBase {
        return ComObjectBase{
            .ref_count = 1,
            .allocator = allocator,
        };
    }

    pub fn addRef(self: *ComObjectBase) u32 {
        self.ref_count += 1;
        return self.ref_count;
    }

    pub fn release(self: *ComObjectBase) u32 {
        self.ref_count -= 1;
        const ref_count = self.ref_count;

        if (ref_count == 0) {
            // Object should be destroyed by the implementing type
            return 0;
        }

        return ref_count;
    }

    pub fn queryInterfaceBase(riid: *const GUID, ppvObject: *?*anyopaque, self_ptr: *anyopaque, supported_interfaces: []const GUID) HRESULT {
        // Check for supported interfaces
        for (supported_interfaces) |iid| {
            if (std.mem.eql(u8, std.mem.asBytes(riid), std.mem.asBytes(&iid))) {
                ppvObject.* = self_ptr;
                return winrt_core.S_OK;
            }
        }

        ppvObject.* = null;
        return @bitCast(winrt_core.E_NOINTERFACE);
    }
};

// Helper for implementing IInspectable methods
pub const InspectableHelpers = struct {
    pub fn getIidsEmpty(iidCount: *u32, iids: *?**GUID) HRESULT {
        iidCount.* = 0;
        iids.* = null;
        return winrt_core.S_OK;
    }

    pub fn getRuntimeClassNameEmpty(className: *HSTRING) HRESULT {
        className.* = null;
        return winrt_core.S_OK;
    }

    pub fn getTrustLevelBasic(trustLevel: *TrustLevel) HRESULT {
        trustLevel.* = TrustLevel.BaseTrust;
        return winrt_core.S_OK;
    }
};
