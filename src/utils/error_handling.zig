const std = @import("std");
const winrt_core = @import("../core/winrt_core.zig");

const HRESULT = winrt_core.HRESULT;

// Comprehensive error handling for UWP applications
pub const UWPError = error{
    // Initialization errors
    ComInitializationFailed,
    WinRTInitializationFailed,

    // Factory and activation errors
    FactoryCreationFailed,
    ActivationFailed,
    QueryInterfaceFailed,

    // Application lifecycle errors
    ApplicationStartupFailed,
    ViewCreationFailed,
    WindowActivationFailed,
    MessageLoopFailed,

    // Resource management errors
    MemoryAllocationFailed,
    ResourceCleanupFailed,

    // UI and rendering errors
    UIInitializationFailed,
    RenderingFailed,
    LayoutFailed,

    // General errors
    NotImplemented,
    InvalidArgument,
    UnexpectedState,
    OperationCancelled,
    AccessDenied,

    // System integration errors
    SystemCallFailed,
    DeviceNotReady,
    ServiceUnavailable,
};

// Error context for better debugging
pub const ErrorContext = struct {
    error_code: HRESULT,
    operation: []const u8,
    component: []const u8,
    additional_info: ?[]const u8,

    pub fn init(error_code: HRESULT, operation: []const u8, component: []const u8) ErrorContext {
        return ErrorContext{
            .error_code = error_code,
            .operation = operation,
            .component = component,
            .additional_info = null,
        };
    }

    pub fn withAdditionalInfo(self: ErrorContext, additional_info: []const u8) ErrorContext {
        return ErrorContext{
            .error_code = self.error_code,
            .operation = self.operation,
            .component = self.component,
            .additional_info = additional_info,
        };
    }

    pub fn print(self: *const ErrorContext) void {
        std.debug.print("ERROR in {s}::{s} - HRESULT: 0x{X} ({s})\n", .{ self.component, self.operation, self.error_code, hrToString(self.error_code) });

        if (self.additional_info) |info| {
            std.debug.print("  Additional info: {s}\n", .{info});
        }
    }
};

// Convert HRESULT to human-readable string
pub fn hrToString(hr: HRESULT) []const u8 {
    return switch (@as(u32, @bitCast(hr))) {
        0x00000000 => "S_OK - Success",
        0x00000001 => "S_FALSE - Success with warning",
        0x80004005 => "E_FAIL - General failure",
        0x80004002 => "E_NOINTERFACE - Interface not supported",
        0x80070005 => "E_ACCESSDENIED - Access denied",
        0x8007000E => "E_OUTOFMEMORY - Out of memory",
        0x80070057 => "E_INVALIDARG - Invalid argument",
        0x80004001 => "E_NOTIMPL - Not implemented",
        0x80010106 => "RPC_E_CHANGED_MODE - COM mode already set",
        0x8001010E => "RPC_E_WRONG_THREAD - Wrong thread for operation",
        0x80040154 => "REGDB_E_CLASSNOTREG - Class not registered",
        0x800401F0 => "CO_E_NOTINITIALIZED - COM not initialized",
        else => "Unknown HRESULT",
    };
}

// Error handler with automatic logging
pub const ErrorHandler = struct {
    allocator: std.mem.Allocator,
    error_history: std.ArrayList(ErrorContext),

    pub fn init(allocator: std.mem.Allocator) ErrorHandler {
        return ErrorHandler{
            .allocator = allocator,
            .error_history = std.ArrayList(ErrorContext).init(allocator),
        };
    }

    pub fn deinit(self: *ErrorHandler) void {
        self.error_history.deinit();
    }

    pub fn handleError(self: *ErrorHandler, error_context: ErrorContext) UWPError {
        // Log the error
        error_context.print();

        // Store in history
        self.error_history.append(error_context) catch {
            std.debug.print("Failed to store error in history\n", .{});
        };

        // Convert to UWPError
        return hrToUWPError(error_context.error_code);
    }

    pub fn printErrorHistory(self: *ErrorHandler) void {
        std.debug.print("\n=== Error History ===\n", .{});
        for (self.error_history.items, 0..) |error_ctx, i| {
            std.debug.print("{}. ", .{i + 1});
            error_ctx.print();
        }
        std.debug.print("=====================\n\n", .{});
    }
};

// Convert HRESULT to UWPError
pub fn hrToUWPError(hr: HRESULT) UWPError {
    return switch (@as(u32, @bitCast(hr))) {
        0x80004005 => UWPError.ApplicationStartupFailed,
        0x80004002 => UWPError.QueryInterfaceFailed,
        0x80070005 => UWPError.AccessDenied,
        0x8007000E => UWPError.MemoryAllocationFailed,
        0x80070057 => UWPError.InvalidArgument,
        0x80004001 => UWPError.NotImplemented,
        0x80010106 => UWPError.ComInitializationFailed,
        0x8001010E => UWPError.ApplicationStartupFailed,
        0x80040154 => UWPError.FactoryCreationFailed,
        0x800401F0 => UWPError.ComInitializationFailed,
        else => UWPError.SystemCallFailed,
    };
}

// Macro-like function for easy error handling
pub fn checkHResult(hr: HRESULT, operation: []const u8, component: []const u8, error_handler: *ErrorHandler) UWPError!void {
    if (winrt_core.isFailure(hr)) {
        const error_context = ErrorContext.init(hr, operation, component);
        return error_handler.handleError(error_context);
    }
}
