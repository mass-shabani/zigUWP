// src/core/com_base.zig
// COM/WinRT base types and utilities
// Provides foundation for all COM objects

const std = @import("std");
const winrt = @import("winrt_core.zig");

// ============================================================================
// Well-Known Interface IIDs
// ============================================================================

pub const IID_IUnknown = winrt.GUID{
    .Data1 = 0x00000000,
    .Data2 = 0x0000,
    .Data3 = 0x0000,
    .Data4 = .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 },
};

pub const IID_IInspectable = winrt.GUID{
    .Data1 = 0xAF86E2E0,
    .Data2 = 0xB12D,
    .Data3 = 0x4C6A,
    .Data4 = .{ 0x9C, 0x5A, 0xD7, 0xAA, 0x65, 0x10, 0x1E, 0x90 },
};

pub const IID_IActivationFactory = winrt.GUID{
    .Data1 = 0x00000035,
    .Data2 = 0x0000,
    .Data3 = 0x0000,
    .Data4 = .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 },
};

// ============================================================================
// IUnknown - Base COM Interface
// ============================================================================

pub const IUnknown = extern struct {
    vtbl: *const VTable,

    pub const VTable = extern struct {
        QueryInterface: *const fn (
            *IUnknown,
            *const winrt.GUID,
            *?*anyopaque,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        AddRef: *const fn (
            *IUnknown,
        ) callconv(winrt.WINAPI) u32,

        Release: *const fn (
            *IUnknown,
        ) callconv(winrt.WINAPI) u32,
    };

    // Inline helper methods
    pub inline fn queryInterface(
        self: *IUnknown,
        riid: *const winrt.GUID,
        ppv: *?*anyopaque,
    ) winrt.HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppv);
    }

    pub inline fn addRef(self: *IUnknown) u32 {
        return self.vtbl.AddRef(self);
    }

    pub inline fn release(self: *IUnknown) u32 {
        return self.vtbl.Release(self);
    }
};

// ============================================================================
// IInspectable - Base WinRT Interface
// ============================================================================

pub const IInspectable = extern struct {
    vtbl: *const VTable,

    pub const VTable = extern struct {
        // IUnknown
        QueryInterface: *const fn (
            *IInspectable,
            *const winrt.GUID,
            *?*anyopaque,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        AddRef: *const fn (
            *IInspectable,
        ) callconv(winrt.WINAPI) u32,

        Release: *const fn (
            *IInspectable,
        ) callconv(winrt.WINAPI) u32,

        // IInspectable
        GetIids: *const fn (
            *IInspectable,
            *u32,
            *?[*]winrt.GUID,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetRuntimeClassName: *const fn (
            *IInspectable,
            *winrt.HSTRING,
        ) callconv(winrt.WINAPI) winrt.HRESULT,

        GetTrustLevel: *const fn (
            *IInspectable,
            *winrt.TrustLevel,
        ) callconv(winrt.WINAPI) winrt.HRESULT,
    };

    // Inline helper methods
    pub inline fn queryInterface(
        self: *IInspectable,
        riid: *const winrt.GUID,
        ppv: *?*anyopaque,
    ) winrt.HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppv);
    }

    pub inline fn addRef(self: *IInspectable) u32 {
        return self.vtbl.AddRef(self);
    }

    pub inline fn release(self: *IInspectable) u32 {
        return self.vtbl.Release(self);
    }

    pub inline fn getIids(
        self: *IInspectable,
        count: *u32,
        iids: *?[*]winrt.GUID,
    ) winrt.HRESULT {
        return self.vtbl.GetIids(self, count, iids);
    }

    pub inline fn getRuntimeClassName(
        self: *IInspectable,
        name: *winrt.HSTRING,
    ) winrt.HRESULT {
        return self.vtbl.GetRuntimeClassName(self, name);
    }

    pub inline fn getTrustLevel(
        self: *IInspectable,
        level: *winrt.TrustLevel,
    ) winrt.HRESULT {
        return self.vtbl.GetTrustLevel(self, level);
    }
};

// ============================================================================
// COM Object Base - Reference Counting Helper
// ============================================================================

pub const ComObject = struct {
    ref_count: std.atomic.Value(u32),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ComObject {
        return .{
            .ref_count = std.atomic.Value(u32).init(1),
            .allocator = allocator,
        };
    }

    pub fn addRef(self: *ComObject) u32 {
        const new_count = self.ref_count.fetchAdd(1, .monotonic) + 1;
        return new_count;
    }

    pub fn release(self: *ComObject) u32 {
        const old_count = self.ref_count.fetchSub(1, .release);
        const new_count = old_count - 1;

        return new_count;
    }

    pub fn getRefCount(self: *const ComObject) u32 {
        return self.ref_count.load(.monotonic);
    }
};

// ============================================================================
// QueryInterface Helper
// ============================================================================

pub fn queryInterfaceHelper(
    riid: *const winrt.GUID,
    ppv: *?*anyopaque,
    self_ptr: *anyopaque,
    supported_iids: []const winrt.GUID,
) winrt.HRESULT {
    for (supported_iids) |iid| {
        if (winrt.guidEqual(riid, &iid)) {
            ppv.* = self_ptr;
            return winrt.S_OK;
        }
    }

    ppv.* = null;
    return @bitCast(winrt.E_NOINTERFACE);
}

// ============================================================================
// IInspectable Default Implementations
// ============================================================================

pub const InspectableDefaults = struct {
    /// Returns no IIDs (for simple objects)
    pub fn getIidsEmpty(
        _: *IInspectable,
        count: *u32,
        iids: *?[*]winrt.GUID,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        count.* = 0;
        iids.* = null;
        return winrt.S_OK;
    }

    /// Returns null runtime class name
    pub fn getRuntimeClassNameEmpty(
        _: *IInspectable,
        name: *winrt.HSTRING,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        name.* = null;
        return winrt.S_OK;
    }

    /// Returns BaseTrust level
    pub fn getTrustLevelBase(
        _: *IInspectable,
        level: *winrt.TrustLevel,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        level.* = .BaseTrust;
        return winrt.S_OK;
    }

    /// Returns FullTrust level
    pub fn getTrustLevelFull(
        _: *IInspectable,
        level: *winrt.TrustLevel,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        level.* = .FullTrust;
        return winrt.S_OK;
    }
};

// ============================================================================
// Smart Pointers (RAII Wrappers)
// ============================================================================

/// RAII wrapper for IUnknown-derived interfaces
pub fn ComPtr(comptime T: type) type {
    return struct {
        ptr: ?*T,

        const Self = @This();

        pub fn init(ptr: ?*T) Self {
            if (ptr) |p| {
                const unk: *IUnknown = @ptrCast(p);
                _ = unk.addRef();
            }
            return .{ .ptr = ptr };
        }

        pub fn deinit(self: *Self) void {
            if (self.ptr) |p| {
                const unk: *IUnknown = @ptrCast(p);
                _ = unk.release();
                self.ptr = null;
            }
        }

        pub fn get(self: *const Self) ?*T {
            return self.ptr;
        }

        pub fn attach(self: *Self, ptr: ?*T) void {
            self.deinit();
            self.ptr = ptr;
        }

        pub fn detach(self: *Self) ?*T {
            const ptr = self.ptr;
            self.ptr = null;
            return ptr;
        }

        pub fn copyTo(self: *const Self, out: *?*T) void {
            out.* = self.ptr;
            if (self.ptr) |p| {
                const unk: *IUnknown = @ptrCast(p);
                _ = unk.addRef();
            }
        }
    };
}
