// src/implementation/application.zig
const std = @import("std");
const winrt_core = @import("../core/winrt_core.zig");
const activation = @import("../core/activation.zig");
const uwp_application = @import("../core/uwp_application.zig");
const com_base = @import("../core/com_base.zig");
const hstring = @import("../utils/hstring.zig");
const logger = @import("../utils/debug_logger.zig");

const WINAPI = winrt_core.WINAPI;
const HRESULT = winrt_core.HRESULT;
const GUID = winrt_core.GUID;
const HSTRING = winrt_core.HSTRING;
const TrustLevel = winrt_core.TrustLevel;

// IApplication interface (simplified)
pub const IApplication = extern struct {
    vtbl: *const IApplicationVtbl,

    pub const IApplicationVtbl = extern struct {
        // IInspectable methods
        QueryInterface: *const fn (*IApplication, *const GUID, *?*anyopaque) callconv(WINAPI) HRESULT,
        AddRef: *const fn (*IApplication) callconv(WINAPI) u32,
        Release: *const fn (*IApplication) callconv(WINAPI) u32,
        GetIids: *const fn (*IApplication, *u32, *?**GUID) callconv(WINAPI) HRESULT,
        GetRuntimeClassName: *const fn (*IApplication, *HSTRING) callconv(WINAPI) HRESULT,
        GetTrustLevel: *const fn (*IApplication, *TrustLevel) callconv(WINAPI) HRESULT,

        // IApplication methods
        OnLaunched: *const fn (*IApplication, *anyopaque) callconv(WINAPI) void,
    };
};

// Application implementation
pub const UWPApplicationImpl = struct {
    ref_count: u32,
    allocator: std.mem.Allocator,

    pub fn create(allocator: std.mem.Allocator) !*IApplication {
        const app = try allocator.create(UWPApplicationImpl);
        app.* = UWPApplicationImpl{
            .ref_count = 1,
            .allocator = allocator,
        };

        const app_interface = try allocator.create(IApplication);
        app_interface.* = IApplication{
            .vtbl = &vtbl,
        };

        // Store the implementation in the interface (hack for simplicity)
        // In real COM, this would be different
        @as(*?*anyopaque, @ptrCast(app_interface)).* = app;

        return app_interface;
    }

    fn queryInterface(self: *IApplication, riid: *const GUID, ppvObject: *?*anyopaque) callconv(WINAPI) HRESULT {
        if (std.mem.eql(u8, std.mem.asBytes(riid), std.mem.asBytes(&com_base.IID_IUnknown)) or
            std.mem.eql(u8, std.mem.asBytes(riid), std.mem.asBytes(&com_base.IID_IInspectable)))
        {
            _ = self.vtbl.AddRef(self);
            ppvObject.* = self;
            return winrt_core.S_OK;
        }
        ppvObject.* = null;
        return winrt_core.E_NOINTERFACE;
    }

    fn addRef(self: *IApplication) callconv(WINAPI) u32 {
        const impl = @as(*UWPApplicationImpl, @alignCast(@ptrCast(@as(*?*anyopaque, @ptrCast(self)).*)));
        impl.ref_count += 1;
        return impl.ref_count;
    }

    fn release(self: *IApplication) callconv(WINAPI) u32 {
        const impl = @as(*UWPApplicationImpl, @alignCast(@ptrCast(@as(*?*anyopaque, @ptrCast(self)).*)));
        impl.ref_count -= 1;
        if (impl.ref_count == 0) {
            impl.allocator.destroy(impl);
            impl.allocator.destroy(self);
        }
        return impl.ref_count;
    }

    fn getIids(self: *IApplication, iidCount: *u32, iids: *?**GUID) callconv(WINAPI) HRESULT {
        _ = self;
        _ = iidCount;
        _ = iids;
        return winrt_core.E_NOTIMPL;
    }

    fn getRuntimeClassName(self: *IApplication, className: *HSTRING) callconv(WINAPI) HRESULT {
        _ = self;
        const name = "ZigUWP.ModularApp.App";
        const hstr = hstring.create(name) catch return winrt_core.E_FAIL;
        className.* = hstr;
        return winrt_core.S_OK;
    }

    fn getTrustLevel(self: *IApplication, trustLevel: *TrustLevel) callconv(WINAPI) HRESULT {
        _ = self;
        trustLevel.* = .FullTrust;
        return winrt_core.S_OK;
    }

    fn onLaunched(self: *IApplication, args: *anyopaque) callconv(WINAPI) void {
        _ = self;
        _ = args;
        logger.info("Application.OnLaunched called", .{});

        // Create and run the UWP application
        const allocator = std.heap.page_allocator; // Use page allocator for simplicity

        var uwp_app = uwp_application.UWPApplication.init(allocator);
        defer uwp_app.deinit();

        uwp_app.startup() catch |err| {
            logger.critical("Failed to startup UWP app: {s}", .{@errorName(err)});
            return;
        };

        uwp_app.createViewSource() catch |err| {
            logger.critical("Failed to create view source: {s}", .{@errorName(err)});
            return;
        };

        uwp_app.run() catch |err| {
            logger.critical("UWP app run failed: {s}", .{@errorName(err)});
            return;
        };

        logger.info("Application completed successfully", .{});
    }
};

const vtbl = IApplication.IApplicationVtbl{
    .QueryInterface = UWPApplicationImpl.queryInterface,
    .AddRef = UWPApplicationImpl.addRef,
    .Release = UWPApplicationImpl.release,
    .GetIids = UWPApplicationImpl.getIids,
    .GetRuntimeClassName = UWPApplicationImpl.getRuntimeClassName,
    .GetTrustLevel = UWPApplicationImpl.getTrustLevel,
    .OnLaunched = UWPApplicationImpl.onLaunched,
};

// Application factory
pub const ApplicationFactory = struct {
    ref_count: u32,
    allocator: std.mem.Allocator,

    pub fn create(allocator: std.mem.Allocator) !*activation.IActivationFactory {
        const factory = try allocator.create(ApplicationFactory);
        factory.* = ApplicationFactory{
            .ref_count = 1,
            .allocator = allocator,
        };

        const factory_interface = try allocator.create(activation.IActivationFactory);
        factory_interface.* = activation.IActivationFactory{
            .vtbl = &factory_vtbl,
        };

        // Store the implementation
        @as(*?*anyopaque, @ptrCast(factory_interface)).* = factory;

        return factory_interface;
    }

    fn queryInterface(self: *activation.IActivationFactory, riid: *const GUID, ppvObject: *?*anyopaque) callconv(WINAPI) HRESULT {
        if (std.mem.eql(u8, std.mem.asBytes(riid), std.mem.asBytes(&com_base.IID_IUnknown)) or
            std.mem.eql(u8, std.mem.asBytes(riid), std.mem.asBytes(&com_base.IID_IInspectable)) or
            std.mem.eql(u8, std.mem.asBytes(riid), std.mem.asBytes(&com_base.IID_IActivationFactory)))
        {
            _ = self.vtbl.AddRef(self);
            ppvObject.* = self;
            return winrt_core.S_OK;
        }
        ppvObject.* = null;
        return winrt_core.E_NOINTERFACE;
    }

    fn addRef(self: *activation.IActivationFactory) callconv(WINAPI) u32 {
        const impl = @as(*ApplicationFactory, @alignCast(@ptrCast(@as(*?*anyopaque, @ptrCast(self)).*)));
        impl.ref_count += 1;
        return impl.ref_count;
    }

    fn release(self: *activation.IActivationFactory) callconv(WINAPI) u32 {
        const impl = @as(*ApplicationFactory, @alignCast(@ptrCast(@as(*?*anyopaque, @ptrCast(self)).*)));
        impl.ref_count -= 1;
        if (impl.ref_count == 0) {
            impl.allocator.destroy(impl);
            impl.allocator.destroy(self);
        }
        return impl.ref_count;
    }

    fn getIids(self: *activation.IActivationFactory, iidCount: *u32, iids: *?**GUID) callconv(WINAPI) HRESULT {
        _ = self;
        _ = iidCount;
        _ = iids;
        return winrt_core.E_NOTIMPL;
    }

    fn getRuntimeClassName(self: *activation.IActivationFactory, className: *HSTRING) callconv(WINAPI) HRESULT {
        _ = self;
        const name = "ZigUWP.ModularApp.App";
        const hstr = hstring.create(name) catch return winrt_core.E_FAIL;
        className.* = hstr;
        return winrt_core.S_OK;
    }

    fn getTrustLevel(self: *activation.IActivationFactory, trustLevel: *TrustLevel) callconv(WINAPI) HRESULT {
        _ = self;
        trustLevel.* = .FullTrust;
        return winrt_core.S_OK;
    }

    fn activateInstance(self: *activation.IActivationFactory, instance: *?*anyopaque) callconv(WINAPI) HRESULT {
        const impl = @as(*ApplicationFactory, @alignCast(@ptrCast(@as(*?*anyopaque, @ptrCast(self)).*)));
        const app = UWPApplicationImpl.create(impl.allocator) catch return winrt_core.E_FAIL;
        instance.* = app;
        return winrt_core.S_OK;
    }
};

const factory_vtbl = activation.IActivationFactory.IActivationFactoryVtbl{
    .QueryInterface = ApplicationFactory.queryInterface,
    .AddRef = ApplicationFactory.addRef,
    .Release = ApplicationFactory.release,
    .GetIids = ApplicationFactory.getIids,
    .GetRuntimeClassName = ApplicationFactory.getRuntimeClassName,
    .GetTrustLevel = ApplicationFactory.getTrustLevel,
    .ActivateInstance = ApplicationFactory.activateInstance,
};
