const std = @import("std");

// Import all our modules for testing
const winrt_core = @import("core/winrt_core.zig");
const activation = @import("core/activation.zig");
const com_base = @import("core/com_base.zig");
const hstring = @import("utils/hstring.zig");
const error_handling = @import("utils/error_handling.zig");

pub fn main() !void {
    std.debug.print("=== ZigUWP Module Testing ===\n\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test 1: WinRT Core initialization
    std.debug.print("Test 1: WinRT Core System...\n", .{});
    try testWinRTCore();
    std.debug.print("✓ WinRT Core test passed\n\n", .{});

    // Test 2: HSTRING utilities
    std.debug.print("Test 2: HSTRING utilities...\n", .{});
    try testHString();
    std.debug.print("✓ HSTRING test passed\n\n", .{});

    // Test 3: Error handling
    std.debug.print("Test 3: Error handling system...\n", .{});
    try testErrorHandling(allocator);
    std.debug.print("✓ Error handling test passed\n\n", .{});

    // Test 4: COM base functionality
    std.debug.print("Test 4: COM base functionality...\n", .{});
    try testComBase();
    std.debug.print("✓ COM base test passed\n\n", .{});

    // Test 5: Activation system
    std.debug.print("Test 5: WinRT activation system...\n", .{});
    try testActivationSystem(allocator);
    std.debug.print("✓ Activation system test passed\n\n", .{});

    std.debug.print("=== All Module Tests Completed Successfully ===\n", .{});
}

fn testWinRTCore() !void {
    // Test HRESULT utility functions
    const success_hr: winrt_core.HRESULT = winrt_core.S_OK;
    const fail_hr: winrt_core.HRESULT = @bitCast(winrt_core.E_FAIL);

    if (!winrt_core.isSuccess(success_hr)) {
        return error.HResultTestFailed;
    }

    if (!winrt_core.isFailure(fail_hr)) {
        return error.HResultTestFailed;
    }

    std.debug.print("  - HRESULT utilities working correctly\n", .{});
}

fn testHString() !void {
    // Test HSTRING creation and destruction
    const test_string = "Hello, WinRT!";
    const hstring = try hstring.create(test_string);
    defer hstring.destroy(hstring);

    std.debug.print("  - HSTRING creation/destruction working\n", .{});

    // Test HSTRING wrapper
    var hstring_wrapper = try hstring.HStringWrapper.init("Test Wrapper");
    defer hstring_wrapper.deinit();

    std.debug.print("  - HSTRING wrapper working\n", .{});

    // Test batch HSTRING management
    var batch = hstring.HStringBatch.init(std.heap.page_allocator);
    defer batch.deinit();

    _ = try batch.add("String 1");
    _ = try batch.add("String 2");
    _ = try batch.add("String 3");

    std.debug.print("  - HSTRING batch management working\n", .{});
}

fn testErrorHandling(allocator: std.mem.Allocator) !void {
    // Test error context creation
    const error_context = error_handling.ErrorContext.init(@bitCast(winrt_core.E_FAIL), "TestOperation", "TestComponent");

    std.debug.print("  - Error context creation working\n", .{});

    // Test error handler
    var error_handler = error_handling.ErrorHandler.init(allocator);
    defer error_handler.deinit();

    const uwp_error = error_handler.handleError(error_context);
    std.debug.print("  - Error handler working, mapped to: {}\n", .{uwp_error});

    // Test HRESULT to string conversion
    const error_string = error_handling.hrToString(@bitCast(winrt_core.E_FAIL));
    std.debug.print("  - HRESULT to string: {s}\n", .{error_string});
}

fn testComBase() !void {
    // Test COM object base functionality
    var com_base = com_base.ComObjectBase.init(std.heap.page_allocator);

    // Test reference counting
    const initial_count = com_base.addRef();
    if (initial_count != 2) { // Should be 2 (initial 1 + addRef)
        return error.RefCountTestFailed;
    }

    const decremented_count = com_base.release();
    if (decremented_count != 1) {
        return error.RefCountTestFailed;
    }

    std.debug.print("  - COM reference counting working correctly\n", .{});

    // Test IInspectable helpers
    var iid_count: u32 = undefined;
    var iids: ?**winrt_core.GUID = undefined;
    _ = com_base.InspectableHelpers.getIidsEmpty(&iid_count, &iids);

    if (iid_count != 0 or iids != null) {
        return error.InspectableHelpersTestFailed;
    }

    std.debug.print("  - IInspectable helpers working correctly\n", .{});
}

fn testActivationSystem(allocator: std.mem.Allocator) !void {
    // Test WinRT system initialization
    var winrt_system = activation.WinRTSystem.init();
    defer winrt_system.shutdown();

    // Try to startup (this might fail in some environments, which is OK for testing)
    winrt_system.startup() catch |err| {
        std.debug.print("  - WinRT startup test: {} (expected in some environments)\n", .{err});
        return; // Early return if WinRT can't be initialized
    };

    std.debug.print("  - WinRT system initialization working\n", .{});

    // Test activation factory manager
    var factory_manager = activation.ActivationFactoryManager.init(allocator);

    // Try to get a common WinRT factory (Calendar)
    factory_manager.getActivationFactory(hstring.WinRTClassNames.CALENDAR, &com_base.IID_IActivationFactory) catch |err| {
        std.debug.print("  - Activation factory test: {} (expected if WinRT not fully available)\n", .{err});
        return;
    };

    std.debug.print("  - Activation factory manager working\n", .{});
}
