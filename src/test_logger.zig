// src\test_logger.zig

// فایل تست برای بررسی عملکرد Logger

const std = @import("std");
const logger = @import("utils/debug_logger.zig");
const windows = std.os.windows;

pub fn main() !void {
    std.debug.print("Testing ZigUWP Logger...\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize logger
    try logger.initGlobalLogger(allocator);
    defer logger.deinitGlobalLogger(allocator);

    // تست سطوح مختلف
    logger.debug("This is a DEBUG message", .{});
    logger.info("This is an INFO message", .{});
    logger.warn("This is a WARNING message", .{});
    logger.err("This is an ERROR message", .{});
    logger.critical("This is a CRITICAL message", .{});

    // تست با فرمت
    const test_value = 42;
    const test_string = "Hello, ZigUWP!";
    logger.info("Test value: {d}, Test string: {s}", .{ test_value, test_string });

    // تست HRESULT logging
    const fake_hr: i32 = @bitCast(@as(u32, 0x80070005)); // E_ACCESSDENIED
    logger.logHRESULT(fake_hr, "TestFunction");

    // تست separator
    if (logger.getLogger()) |log| {
        log.separator('=');
        log.info("Section with separator", .{});
        log.separator('-');
    }

    // System info
    if (logger.getLogger()) |log| {
        log.logSystemInfo();
    }

    std.debug.print("\nLogger test complete!\n", .{});
    std.debug.print("Check the following locations:\n", .{});
    std.debug.print("  1. DebugView (if running as admin)\n", .{});
    std.debug.print("  2. %LOCALAPPDATA%\\ziguwp_debug.log\n", .{});
}
