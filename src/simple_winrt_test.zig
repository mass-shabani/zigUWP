// src\simple_winrt_test.zig
const std = @import("std");
const winrt_core = @import("core/winrt_core.zig");
const hstring = @import("utils/hstring.zig");

pub fn main() !void {
    std.debug.print("=== Simple WinRT Test ===\n\n", .{});

    // Test basic WinRT functionality
    std.debug.print("Testing basic WinRT operations...\n", .{});

    // Test HSTRING creation
    const test_string = "Hello, WinRT from simple test!";
    const hstring_obj = try hstring.create(test_string);
    defer hstring.destroy(hstring_obj);

    std.debug.print("✓ HSTRING created successfully: {s}\n", .{test_string});

    // Test HRESULT utilities
    const success_hr: winrt_core.HRESULT = winrt_core.S_OK;
    const fail_hr: winrt_core.HRESULT = @bitCast(winrt_core.E_FAIL);

    if (winrt_core.isSuccess(success_hr)) {
        std.debug.print("✓ Success HRESULT detected correctly\n", .{});
    } else {
        std.debug.print("✗ Failed to detect success HRESULT\n", .{});
    }

    if (winrt_core.isFailure(fail_hr)) {
        std.debug.print("✓ Failure HRESULT detected correctly\n", .{});
    } else {
        std.debug.print("✗ Failed to detect failure HRESULT\n", .{});
    }

    std.debug.print("\n=== Simple WinRT Test Completed ===\n", .{});
}


