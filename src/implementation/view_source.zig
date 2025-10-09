// src/implementation/view_source.zig
// Implementation of IFrameworkViewSource
// This is the entry point that CoreApplication.Run calls

const std = @import("std");
const winrt = @import("../core/winrt_core.zig");
const com = @import("../core/com_base.zig");
const view_interfaces = @import("../interfaces/view.zig");
const framework_view = @import("framework_view.zig");
const logger = @import("../utils/debug_logger.zig");

// ============================================================================
// ViewSource Implementation
// ============================================================================

pub const ViewSource = struct {
    // COM object
    com_obj: com.ComObject,

    // IFrameworkViewSource interface
    view_source_vtbl: view_interfaces.IFrameworkViewSource.VTable,

    const Self = @This();

    /// Create new ViewSource instance
    pub fn create(allocator: std.mem.Allocator) !*view_interfaces.IFrameworkViewSource {
        logger.info("Creating ViewSource...", .{});

        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = Self{
            .com_obj = com.ComObject.init(allocator),
            .view_source_vtbl = .{
                .QueryInterface = queryInterface,
                .AddRef = addRef,
                .Release = release,
                .GetIids = getIids,
                .GetRuntimeClassName = getRuntimeClassName,
                .GetTrustLevel = getTrustLevel,
                .CreateView = createView,
            },
        };

        logger.debug("ViewSource created successfully", .{});

        // Return as IFrameworkViewSource interface
        return @ptrCast(&self.view_source_vtbl);
    }

    /// Get Self from interface pointer
    fn getSelf(iface: *view_interfaces.IFrameworkViewSource) *Self {
        const iface_vtable: *view_interfaces.IFrameworkViewSource.VTable = @ptrCast(iface);
        return @fieldParentPtr("view_source_vtbl", iface_vtable);
    }

    // ========================================================================
    // IUnknown Implementation
    // ========================================================================

    fn queryInterface(
        iface: *view_interfaces.IFrameworkViewSource,
        riid: *const winrt.GUID,
        ppv: *?*anyopaque,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        const self = getSelf(iface);
        _ = self;

        const supported_iids = [_]winrt.GUID{
            com.IID_IUnknown,
            com.IID_IInspectable,
            view_interfaces.IID_IFrameworkViewSource,
        };

        return com.queryInterfaceHelper(riid, ppv, iface, &supported_iids);
    }

    fn addRef(
        iface: *view_interfaces.IFrameworkViewSource,
    ) callconv(winrt.WINAPI) u32 {
        const self = getSelf(iface);
        return self.com_obj.addRef();
    }

    fn release(
        iface: *view_interfaces.IFrameworkViewSource,
    ) callconv(winrt.WINAPI) u32 {
        const self = getSelf(iface);
        const count = self.com_obj.release();

        if (count == 0) {
            logger.debug("ViewSource ref count = 0, destroying", .{});
            const allocator = self.com_obj.allocator;
            allocator.destroy(self);
        }

        return count;
    }

    // ========================================================================
    // IInspectable Implementation
    // ========================================================================

    fn getIids(
        iface: *view_interfaces.IFrameworkViewSource,
        count: *u32,
        iids: *?[*]winrt.GUID,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        return com.InspectableDefaults.getIidsEmpty(@ptrCast(iface), count, iids);
    }

    fn getRuntimeClassName(
        iface: *view_interfaces.IFrameworkViewSource,
        name: *winrt.HSTRING,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        return com.InspectableDefaults.getRuntimeClassNameEmpty(@ptrCast(iface), name);
    }

    fn getTrustLevel(
        iface: *view_interfaces.IFrameworkViewSource,
        level: *winrt.TrustLevel,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        return com.InspectableDefaults.getTrustLevelBase(@ptrCast(iface), level);
    }

    // ========================================================================
    // IFrameworkViewSource Implementation
    // ========================================================================

    fn createView(
        iface: *view_interfaces.IFrameworkViewSource,
        out: *?*view_interfaces.IFrameworkView,
    ) callconv(winrt.WINAPI) winrt.HRESULT {
        const self = getSelf(iface);

        logger.info("ViewSource.CreateView called", .{});

        // Create FrameworkView
        const view = framework_view.FrameworkView.create(self.com_obj.allocator) catch {
            logger.err("Failed to create FrameworkView", .{});
            out.* = null;
            return @bitCast(winrt.E_FAIL);
        };

        out.* = view;
        logger.info("FrameworkView created successfully", .{});

        return winrt.S_OK;
    }
};
