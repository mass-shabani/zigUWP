// src/core/activation.zig
// WinRT Runtime initialization and activation factory management
// Handles COM/WinRT startup and provides activation factory utilities

const std = @import("std");
const winrt = @import("winrt_core.zig");
const com = @import("com_base.zig");
const hstring_utils = @import("../utils/hstring.zig");
const logger = @import("../utils/debug_logger.zig");

// ============================================================================
// WinRT Runtime Manager
// ============================================================================

pub const Runtime = struct {
    is_initialized: bool,

    const Self = @This();

    pub fn init() Self {
        return .{ .is_initialized = false };
    }

    /// Initialize WinRT runtime (RoInitialize)
    pub fn startup(self: *Self) !void {
        if (self.is_initialized) {
            logger.warn("WinRT runtime already initialized", .{});
            return;
        }

        logger.info("Initializing WinRT runtime...", .{});

        // Initialize WinRT with multi-threaded apartment
        const hr = winrt.RoInitialize(winrt.RO_INIT_MULTITHREADED);

        if (winrt.FAILED(hr)) {
            if (hr == winrt.S_FALSE or hr == @as(winrt.HRESULT, @bitCast(winrt.RPC_E_CHANGED_MODE))) {
                // Already initialized (S_FALSE) or different mode (RPC_E_CHANGED_MODE)
                logger.warn("WinRT already initialized or initialized with different mode: 0x{X:0>8}", .{@as(u32, @bitCast(hr))});
                self.is_initialized = true;
                return;
            }

            logger.err("RoInitialize failed: 0x{X:0>8}", .{@as(u32, @bitCast(hr))});
            return error.WinRTInitializationFailed;
        }

        self.is_initialized = true;
        logger.info("WinRT runtime initialized successfully", .{});
    }

    /// Shutdown WinRT runtime
    pub fn shutdown(self: *Self) void {
        if (!self.is_initialized) {
            return;
        }

        logger.info("Shutting down WinRT runtime...", .{});
        winrt.RoUninitialize();
        self.is_initialized = false;
        logger.debug("WinRT runtime shut down", .{});
    }
};

// ============================================================================
// Activation Factory Helper
// ============================================================================

pub const ActivationFactory = struct {
    /// Get activation factory for a runtime class
    pub fn get(
        allocator: std.mem.Allocator,
        class_name: []const u8,
        iid: *const winrt.GUID,
    ) !*anyopaque {
        logger.debug("Getting activation factory for: {s}", .{class_name});

        // Create HSTRING for class name
        const hstr = try hstring_utils.create(allocator, class_name);
        defer hstring_utils.destroy(hstr);

        // Get activation factory
        var factory: ?*anyopaque = null;
        const hr = winrt.RoGetActivationFactory(hstr, iid, &factory);

        if (winrt.FAILED(hr)) {
            logger.err("RoGetActivationFactory failed for {s}: 0x{X:0>8}", .{
                class_name,
                @as(u32, @bitCast(hr)),
            });

            // Provide helpful error messages
            if (hr == @as(winrt.HRESULT, @bitCast(@as(u32, 0x80040154)))) {
                logger.err("  Error: REGDB_E_CLASSNOTREG - Class not registered", .{});
                logger.err("  This usually means:", .{});
                logger.err("    1. The app is not running as UWP", .{});
                logger.err("    2. The runtime class is not available", .{});
                logger.err("    3. Missing dependencies", .{});
            }

            return error.ActivationFactoryNotFound;
        }

        if (factory == null) {
            logger.err("RoGetActivationFactory returned null factory", .{});
            return error.NullActivationFactory;
        }

        logger.debug("Activation factory obtained successfully", .{});
        return factory.?;
    }

    /// Activate an instance of a runtime class
    pub fn activate(
        allocator: std.mem.Allocator,
        class_name: []const u8,
    ) !*anyopaque {
        logger.debug("Activating instance of: {s}", .{class_name});

        // Create HSTRING for class name
        const hstr = try hstring_utils.create(allocator, class_name);
        defer hstring_utils.destroy(hstr);

        // Activate instance
        var instance: ?*anyopaque = null;
        const hr = winrt.RoActivateInstance(hstr, &instance);

        if (winrt.FAILED(hr)) {
            logger.err("RoActivateInstance failed for {s}: 0x{X:0>8}", .{
                class_name,
                @as(u32, @bitCast(hr)),
            });
            return error.ActivationFailed;
        }

        if (instance == null) {
            logger.err("RoActivateInstance returned null instance", .{});
            return error.NullInstance;
        }

        logger.debug("Instance activated successfully", .{});
        return instance.?;
    }
};

// ============================================================================
// Common WinRT Class Names
// ============================================================================

pub const RuntimeClass = struct {
    pub const CORE_APPLICATION = "Windows.ApplicationModel.Core.CoreApplication";
    pub const CORE_APPLICATION_VIEW = "Windows.ApplicationModel.Core.CoreApplicationView";
    pub const CORE_WINDOW = "Windows.UI.Core.CoreWindow";
    pub const CORE_DISPATCHER = "Windows.UI.Core.CoreDispatcher";

    // XAML (for future)
    pub const XAML_APPLICATION = "Windows.UI.Xaml.Application";
    pub const XAML_WINDOW = "Windows.UI.Xaml.Window";

    // WinUI 3 (for future)
    pub const WINUI_APPLICATION = "Microsoft.UI.Xaml.Application";
    pub const WINUI_WINDOW = "Microsoft.UI.Xaml.Window";
};
