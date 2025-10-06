const std = @import("std");
const winrt_core = @import("winrt_core.zig");
const com_base = @import("com_base.zig");
const hstring = @import("../utils/hstring.zig");

const WINAPI = winrt_core.WINAPI;
const HRESULT = winrt_core.HRESULT;
const GUID = winrt_core.GUID;
const HSTRING = winrt_core.HSTRING;
const TrustLevel = winrt_core.TrustLevel;
const S_OK = winrt_core.S_OK;

// IActivationFactory interface
pub const IActivationFactory = extern struct {
    vtbl: *const IActivationFactoryVtbl,

    pub const IActivationFactoryVtbl = extern struct {
        // IUnknown methods
        QueryInterface: *const fn (*IActivationFactory, *const GUID, *?*anyopaque) callconv(WINAPI) HRESULT,

        AddRef: *const fn (*IActivationFactory) callconv(WINAPI) u32,
        Release: *const fn (*IActivationFactory) callconv(WINAPI) u32,

        // IInspectable methods
        GetIids: *const fn (*IActivationFactory, *u32, *?**GUID) callconv(WINAPI) HRESULT,

        GetRuntimeClassName: *const fn (*IActivationFactory, *HSTRING) callconv(WINAPI) HRESULT,

        GetTrustLevel: *const fn (*IActivationFactory, *TrustLevel) callconv(WINAPI) HRESULT,

        // IActivationFactory methods
        ActivateInstance: *const fn (*IActivationFactory, *?*anyopaque) callconv(WINAPI) HRESULT,
    };

    // Helper methods
    pub fn queryInterface(self: *IActivationFactory, riid: *const GUID, ppvObject: *?*anyopaque) HRESULT {
        return self.vtbl.QueryInterface(self, riid, ppvObject);
    }

    pub fn addRef(self: *IActivationFactory) u32 {
        return self.vtbl.AddRef(self);
    }

    pub fn release(self: *IActivationFactory) u32 {
        return self.vtbl.Release(self);
    }

    pub fn activateInstance(self: *IActivationFactory, instance: *?*anyopaque) HRESULT {
        return self.vtbl.ActivateInstance(self, instance);
    }
};

// Activation factory manager
pub const ActivationFactoryManager = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ActivationFactoryManager {
        return ActivationFactoryManager{
            .allocator = allocator,
        };
    }

    pub fn getActivationFactory(self: *ActivationFactoryManager, class_name: []const u8, iid: *const GUID) !*anyopaque {
        // Create HSTRING for the class name
        const hstring_class = try hstring.create(class_name);
        defer hstring.destroy(hstring_class);

        // Get the activation factory
        var factory: ?*anyopaque = null;
        const hr = winrt_core.RoGetActivationFactory(hstring_class, iid, &factory);

        if (winrt_core.isFailure(hr)) {
            std.debug.print("Failed to get activation factory for {s}. HRESULT: 0x{X}\n", .{ class_name, hr });
            return winrt_core.hrToError(hr);
        }

        // Use self to avoid unused parameter warning
        _ = self;

        return factory orelse error.NullFactory;
    }

    pub fn createInstance(self: *ActivationFactoryManager, class_name: []const u8, instance_iid: *const GUID) !*anyopaque {
        // Get the activation factory
        const factory_ptr = try self.getActivationFactory(class_name, &com_base.IID_IActivationFactory);
        const factory: *IActivationFactory = @alignCast(@ptrCast(factory_ptr));
        defer _ = factory.release();

        // Create the instance
        var raw_instance: ?*anyopaque = null;
        const hr = factory.activateInstance(&raw_instance);

        if (winrt_core.isFailure(hr)) {
            std.debug.print("Failed to create instance of {s}. HRESULT: 0x{X}\n", .{ class_name, hr });
            return winrt_core.hrToError(hr);
        }

        const instance = raw_instance orelse return error.NullInstance;

        // Query for the desired interface if different from the raw instance
        if (instance_iid != &com_base.IID_IInspectable) {
            var typed_instance: ?*anyopaque = null;
            const unknown: *com_base.IUnknown = @alignCast(@ptrCast(instance));
            const query_hr = unknown.queryInterface(instance_iid, &typed_instance);

            // Release the original instance
            _ = unknown.release();

            if (winrt_core.isFailure(query_hr)) {
                std.debug.print("Failed to query interface for instance. HRESULT: 0x{X}\n", .{query_hr});
                return winrt_core.hrToError(query_hr);
            }

            return typed_instance orelse error.QueryInterfaceFailed;
        }

        return instance;
    }
};

// WinRT system manager
pub const WinRTSystem = struct {
    is_initialized: bool,
    com_initialized: bool,

    pub fn init() WinRTSystem {
        return WinRTSystem{
            .is_initialized = false,
            .com_initialized = false,
        };
    }

    pub fn startup(self: *WinRTSystem) !void {
        // Initialize COM first
        const com_hr = winrt_core.CoInitializeEx(null, winrt_core.COINIT_APARTMENTTHREADED);
        if (winrt_core.isFailure(com_hr) and com_hr != @as(HRESULT, @bitCast(winrt_core.RPC_E_CHANGED_MODE))) {
            std.debug.print("COM initialization failed: 0x{X}\n", .{com_hr});
            return winrt_core.hrToError(com_hr);
        }

        self.com_initialized = true;
        std.debug.print("COM initialized successfully\n", .{});

        // Initialize WinRT
        const rt_hr = winrt_core.RoInitialize(winrt_core.RO_INIT_SINGLETHREADED);
        if (winrt_core.isFailure(rt_hr) and rt_hr != winrt_core.S_FALSE) {
            std.debug.print("WinRT initialization failed: 0x{X}\n", .{rt_hr});
            return winrt_core.hrToError(rt_hr);
        }

        if (rt_hr == winrt_core.S_FALSE) {
            std.debug.print("WinRT was already initialized\n", .{});
        } else {
            std.debug.print("WinRT initialized successfully\n", .{});
        }

        self.is_initialized = true;
    }

    pub fn shutdown(self: *WinRTSystem) void {
        if (self.is_initialized) {
            winrt_core.RoUninitialize();
            self.is_initialized = false;
            std.debug.print("WinRT uninitialized\n", .{});
        }

        if (self.com_initialized) {
            winrt_core.CoUninitialize();
            self.com_initialized = false;
            std.debug.print("COM uninitialized\n", .{});
        }
    }
};

// Registration functions
pub const ActivationFactoryInfo = struct {
    class_id: []const u8,
    factory: *anyopaque,
};

pub fn registerActivationFactories(
    allocator: std.mem.Allocator,
    factories: []const ActivationFactoryInfo,
) !winrt_core.RO_REGISTRATION_COOKIE {
    const count = factories.len;
    const class_ids = try allocator.alloc(winrt_core.HSTRING, count);
    defer {
        for (class_ids) |h| hstring.destroy(h);
        allocator.free(class_ids);
    }

    const factory_ptrs = try allocator.alloc(*anyopaque, count);
    defer allocator.free(factory_ptrs);

    for (factories, 0..) |f, i| {
        class_ids[i] = try hstring.create(f.class_id);
        factory_ptrs[i] = f.factory;
    }

    var cookie: winrt_core.RO_REGISTRATION_COOKIE = 0;
    const hr = winrt_core.RoRegisterActivationFactories(
        class_ids.ptr,
        factory_ptrs.ptr,
        @intCast(count),
        &cookie,
    );

    if (winrt_core.isFailure(hr)) return winrt_core.hrToError(hr);
    return cookie;
}

pub fn revokeActivationFactories(cookie: winrt_core.RO_REGISTRATION_COOKIE) void {
    winrt_core.RoRevokeActivationFactories(cookie);
}
