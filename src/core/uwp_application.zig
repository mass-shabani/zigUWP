// src/core/uwp_application.zig
const std = @import("std");
const winrt_core = @import("winrt_core.zig");
const activation = @import("activation.zig");
const com_base = @import("com_base.zig");
const application_interfaces = @import("../interfaces/application.zig");
const view_interfaces = @import("../interfaces/view.zig");
const framework_view_impl = @import("../implementation/framework_view.zig");
const view_source_impl = @import("../implementation/view_source.zig");
const application_impl = @import("../implementation/application.zig");
const error_handling = @import("../utils/error_handling.zig");
const logger = @import("../utils/debug_logger.zig");

// UWP Application Manager
pub const UWPApplication = struct {
    allocator: std.mem.Allocator,
    winrt_system: activation.WinRTSystem,
    core_app_manager: application_interfaces.CoreApplicationManager,
    error_handler: error_handling.ErrorHandler,
    view_source: ?*view_source_impl.UWPFrameworkViewSource,
    activation_cookie: ?winrt_core.RO_REGISTRATION_COOKIE,

    pub fn init(allocator: std.mem.Allocator) UWPApplication {
        logger.info("Creating UWPApplication instance", .{});

        return UWPApplication{
            .allocator = allocator,
            .winrt_system = activation.WinRTSystem.init(),
            .core_app_manager = application_interfaces.CoreApplicationManager.init(allocator),
            .error_handler = error_handling.ErrorHandler.init(allocator),
            .view_source = null,
            .activation_cookie = null,
        };
    }

    pub fn deinit(self: *UWPApplication) void {
        logger.info("Cleaning up UWPApplication", .{});

        if (self.view_source) |vs| {
            logger.debug("Releasing view source", .{});
            const view_source_interface: *view_interfaces.IFrameworkViewSource = @ptrCast(vs);
            _ = view_source_interface.release();
            self.view_source = null;
        }

        logger.debug("Deinitializing core app manager", .{});
        self.core_app_manager.deinit();

        logger.debug("Deinitializing error handler", .{});
        self.error_handler.deinit();

        logger.debug("Shutting down WinRT system", .{});
        self.winrt_system.shutdown();

        logger.info("UWPApplication cleanup complete", .{});
    }

    pub fn startup(self: *UWPApplication) !void {
        logger.separator('=');
        logger.info("ZigUWP - Pure WinRT UWP Application", .{});
        logger.separator('=');

        logger.info("Initializing WinRT systems...", .{});

        self.winrt_system.startup() catch |err| {
            logger.err("WinRT startup failed: {s}", .{@errorName(err)});
            return err;
        };

        logger.info("WinRT initialization completed successfully", .{});

        // Register activation factory for the Application
        const factory = try application_impl.ApplicationFactory.create(self.allocator);
        self.activation_cookie = try activation.registerActivationFactories(self.allocator, &[_]activation.ActivationFactoryInfo{
            .{
                .class_id = "ZigUWP.ModularApp.App",
                .factory = factory,
            },
        });

        logger.info("Application activation factory registered", .{});
    }

    pub fn createViewSource(self: *UWPApplication) !void {
        logger.info("Creating FrameworkViewSource...", .{});

        self.view_source = view_source_impl.UWPFrameworkViewSource.create(self.allocator) catch |err| {
            logger.err("FrameworkViewSource creation failed: {s}", .{@errorName(err)});
            return err;
        };

        logger.info("FrameworkViewSource created successfully", .{});
    }

    pub fn run(self: *UWPApplication) !void {
        if (self.view_source == null) {
            logger.err("No view source available", .{});
            return error.NoViewSource;
        }

        logger.info("Obtaining CoreApplication interface...", .{});

        const core_app = self.core_app_manager.getCoreApplication() catch |err| {
            logger.err("Failed to get CoreApplication: {s}", .{@errorName(err)});
            return err;
        };
        defer _ = core_app.release();

        logger.info("CoreApplication obtained successfully", .{});
        logger.separator('=');
        logger.info("Starting UWP Application Main Loop", .{});
        logger.separator('=');

        const view_source_interface: *view_interfaces.IFrameworkViewSource = @ptrCast(self.view_source.?);
        _ = view_source_interface.addRef();
        defer _ = view_source_interface.release();

        logger.debug("Calling CoreApplication.Run()...", .{});
        const hr = core_app.run(view_source_interface);

        if (winrt_core.isSuccess(hr)) {
            logger.info("CoreApplication::Run succeeded!", .{});
        } else {
            const hr_u32 = @as(u32, @bitCast(hr));
            logger.err("CoreApplication::Run failed: 0x{X:0>8}", .{hr_u32});
            logger.logHRESULT(hr, "ICoreApplication::Run");

            const error_context = error_handling.ErrorContext.init(hr, "Run", "ICoreApplication");
            return self.error_handler.handleError(error_context);
        }

        logger.separator('=');
        logger.info("UWP Application Completed Successfully", .{});
        logger.separator('=');
    }
};
