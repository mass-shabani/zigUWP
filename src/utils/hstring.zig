// src/utils/hstring.zig
// HSTRING creation and management utilities
// Provides safe wrappers around Windows Runtime string APIs

const std = @import("std");
const winrt = @import("../core/winrt_core.zig");

// ============================================================================
// HSTRING Creation
// ============================================================================

/// Create HSTRING from UTF-8 string
pub fn create(allocator: std.mem.Allocator, utf8: []const u8) !winrt.HSTRING {
    if (utf8.len == 0) {
        return createEmpty();
    }

    // Convert UTF-8 to UTF-16
    const utf16 = try std.unicode.utf8ToUtf16LeAlloc(allocator, utf8);
    defer allocator.free(utf16);

    return createFromUtf16(utf16);
}

/// Create HSTRING from UTF-16 string
pub fn createFromUtf16(utf16: []const u16) !winrt.HSTRING {
    if (utf16.len == 0) {
        return createEmpty();
    }

    var hstr: winrt.HSTRING = null;
    const hr = winrt.WindowsCreateString(
        @ptrCast(utf16.ptr),
        @intCast(utf16.len),
        &hstr,
    );

    if (winrt.FAILED(hr)) {
        return error.HStringCreationFailed;
    }

    return hstr;
}

/// Create empty HSTRING
pub fn createEmpty() !winrt.HSTRING {
    var hstr: winrt.HSTRING = null;
    const empty: [1]u16 = .{0};
    const hr = winrt.WindowsCreateString(@ptrCast(&empty), 0, &hstr);

    if (winrt.FAILED(hr)) {
        return error.HStringCreationFailed;
    }

    return hstr;
}

/// Destroy HSTRING
pub fn destroy(hstr: winrt.HSTRING) void {
    if (hstr) |h| {
        _ = winrt.WindowsDeleteString(h);
    }
}

/// Get length of HSTRING
pub fn getLength(hstr: winrt.HSTRING) u32 {
    if (hstr) |h| {
        return winrt.WindowsGetStringLen(h);
    }
    return 0;
}

/// Get raw UTF-16 buffer from HSTRING
pub fn getRawBuffer(hstr: winrt.HSTRING, length: ?*u32) ?[*:0]const u16 {
    if (hstr) |h| {
        return winrt.WindowsGetStringRawBuffer(h, length);
    }
    return null;
}

/// Check if HSTRING is empty
pub fn isEmpty(hstr: winrt.HSTRING) bool {
    if (hstr == null) return true;
    return winrt.WindowsIsStringEmpty(hstr) != 0;
}

// ============================================================================
// RAII Wrapper
// ============================================================================

/// RAII wrapper for HSTRING
pub const HString = struct {
    handle: winrt.HSTRING,

    const Self = @This();

    /// Create from UTF-8
    pub fn init(allocator: std.mem.Allocator, utf8: []const u8) !Self {
        return .{ .handle = try create(allocator, utf8) };
    }

    /// Create from UTF-16
    pub fn initUtf16(utf16: []const u16) !Self {
        return .{ .handle = try createFromUtf16(utf16) };
    }

    /// Create empty
    pub fn initEmpty() !Self {
        return .{ .handle = try createEmpty() };
    }

    /// Destroy
    pub fn deinit(self: *Self) void {
        destroy(self.handle);
        self.handle = null;
    }

    /// Get handle
    pub fn get(self: *const Self) winrt.HSTRING {
        return self.handle;
    }

    /// Get length
    pub fn len(self: *const Self) u32 {
        return getLength(self.handle);
    }

    /// Check if empty
    pub fn isEmptyStr(self: *const Self) bool {
        return isEmpty(self.handle);
    }

    /// Get raw buffer
    pub fn buffer(self: *const Self) ?[*:0]const u16 {
        return getRawBuffer(self.handle, null);
    }

    /// Convert to UTF-8 (caller owns memory)
    pub fn toUtf8(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        var len_buf: u32 = 0;
        const raw = getRawBuffer(self.handle, &len_buf) orelse return error.NullBuffer;

        const slice = raw[0..len_buf];
        return std.unicode.utf16LeToUtf8Alloc(allocator, slice);
    }
};

// ============================================================================
// Batch Manager
// ============================================================================

/// Manages multiple HSTRINGs
pub const HStringBatch = struct {
    allocator: std.mem.Allocator,
    strings: std.ArrayList(winrt.HSTRING),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .strings = std.ArrayList(winrt.HSTRING).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.strings.items) |hstr| {
            destroy(hstr);
        }
        self.strings.deinit();
    }

    pub fn add(self: *Self, utf8: []const u8) !winrt.HSTRING {
        const hstr = try create(self.allocator, utf8);
        try self.strings.append(hstr);
        return hstr;
    }

    pub fn addUtf16(self: *Self, utf16: []const u16) !winrt.HSTRING {
        const hstr = try createFromUtf16(utf16);
        try self.strings.append(hstr);
        return hstr;
    }

    pub fn clear(self: *Self) void {
        for (self.strings.items) |hstr| {
            destroy(hstr);
        }
        self.strings.clearRetainingCapacity();
    }
};
