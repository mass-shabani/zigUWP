const std = @import("std");
const winrt_core = @import("../core/winrt_core.zig");
const com_base = @import("../core/com_base.zig");
const view_interfaces = @import("../interfaces/view.zig");
const framework_view = @import("framework_view.zig");
const error_handling = @import("../utils/error_handling.zig");

const WINAPI = winrt_core.WINAPI;
const HRESULT = winrt_core.HRESULT;
const GUID = winrt_core.GUID;
const HSTRING = winrt_core.HSTRING;
const TrustLevel = winrt_core.TrustLevel;
const S_OK = winrt_core.S_OK;

// Our custom FrameworkViewSource implementation
pub const UWPFrameworkViewSource = struct {
    vtbl: *const view_interfaces.IFrameworkViewSource.IFrameworkViewSourceVtbl,
    base: com_base.ComObjectBase,

    const Self = @This();

    pub fn create(allocator: std.mem.Allocator) !*Self {
        const instance = try allocator.create(Self);
        instance.* = Self{
            .vtbl = &VTable,
            .base = com_base.ComObjectBase.init(allocator),
        };
        return instance;
    }

    pub fn destroy(self: *Self) void {
        const allocator = self.base.allocator;
        allocator.destroy(self);
    }

    // IUnknown implementation
    fn queryInterface(self: *view_interfaces.IFrameworkViewSource, riid: *const GUID, ppvObject: *?*anyopaque) callconv(WINAPI) HRESULT {
        const supported_interfaces = [_]GUID{
            com_base.IID_IUnknown,
            com_base.IID_IInspectable,
            view_interfaces.IID_IFrameworkViewSource,
        };

        return com_base.ComObjectBase.queryInterfaceBase(riid, ppvObject, self, &supported_interfaces);
    }

    fn addRef(self: *view_interfaces.IFrameworkViewSource) callconv(WINAPI) u32 {
        const instance: *Self = @alignCast(@ptrCast(self));
        return instance.base.addRef();
    }

    fn release(self: *view_interfaces.IFrameworkViewSource) callconv(WINAPI) u32 {
        const instance: *Self = @alignCast(@ptrCast(self));
        const ref_count = instance.base.release();

        if (ref_count == 0) {
            instance.destroy();
        }

        return ref_count;
    }

    // IInspectable implementation
    fn getIids(self: *view_interfaces.IFrameworkViewSource, iidCount: *u32, iids: *?**GUID) callconv(WINAPI) HRESULT {
        _ = self;
        return com_base.InspectableHelpers.getIidsEmpty(iidCount, iids);
    }

    fn getRuntimeClassName(self: *view_interfaces.IFrameworkViewSource, className: *HSTRING) callconv(WINAPI) HRESULT {
        _ = self;
        return com_base.InspectableHelpers.getRuntimeClassNameEmpty(className);
    }

    fn getTrustLevel(self: *view_interfaces.IFrameworkViewSource, trustLevel: *TrustLevel) callconv(WINAPI) HRESULT {
        _ = self;
        return com_base.InspectableHelpers.getTrustLevelBasic(trustLevel);
    }

    // IFrameworkViewSource implementation
    fn createView(self: *view_interfaces.IFrameworkViewSource, view: *?*view_interfaces.IFrameworkView) callconv(WINAPI) HRESULT {
        const instance: *Self = @alignCast(@ptrCast(self));

        std.debug.print("FrameworkViewSource: CreateView called\n", .{});

        // Create our custom FrameworkView
        const framework_view_instance = framework_view.UWPFrameworkView.create(instance.base.allocator) catch |err| {
            std.debug.print("Failed to create FrameworkView: {}\n", .{err});
            view.* = null;
            return @bitCast(winrt_core.E_FAIL);
        };

        view.* = @ptrCast(framework_view_instance);

        std.debug.print("FrameworkViewSource: CreateView completed successfully\n", .{});
        return S_OK;
    }

    // VTable for this implementation
    const VTable = view_interfaces.IFrameworkViewSource.IFrameworkViewSourceVtbl{
        .QueryInterface = queryInterface,
        .AddRef = addRef,
        .Release = release,
        .GetIids = getIids,
        .GetRuntimeClassName = getRuntimeClassName,
        .GetTrustLevel = getTrustLevel,
        .CreateView = createView,
    };
};
