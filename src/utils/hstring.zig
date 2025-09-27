const std = @import("std");
const winrt_core = @import("../core/winrt_core.zig");

const HSTRING = winrt_core.HSTRING;
const LPCWSTR = winrt_core.LPCWSTR;
const HRESULT = winrt_core.HRESULT;
const S_OK = winrt_core.S_OK;

// HSTRING management utilities
pub const HStringError = error{
    CreateStringFailed,
    ConversionFailed,
    InvalidInput,
};

/// Create an HSTRING from a UTF-8 string
pub fn create(utf8_str: []const u8) HStringError!HSTRING {
    if (utf8_str.len == 0) {
        var hstring: HSTRING = null;
<<<<<<< HEAD
        // For empty strings, we need to pass a null pointer of the correct type
        // LPCWSTR is typically [*:0]const u16, so we'll create a dummy variable and cast its address
        var dummy: [1]u16 = undefined;
        const hr = winrt_core.WindowsCreateString(@ptrCast(&dummy), 0, &hstring);
=======
        const empty_str: [1:0]u16 = .{0};
        const hr = winrt_core.WindowsCreateString(&empty_str, 0, &hstring);
>>>>>>> Warp-Edit
        if (hr != S_OK) {
            std.debug.print("WindowsCreateString failed for empty string with HRESULT: 0x{X}\n", .{hr});
            return HStringError.CreateStringFailed;
        }
        return hstring;
    }

    var utf16_buf: [1024]u16 = undefined;
    const utf16_len = std.unicode.utf8ToUtf16Le(utf16_buf[0..], utf8_str) catch |err| {
        std.debug.print("Error converting UTF-8 to UTF-16: {}\n", .{err});
        return HStringError.ConversionFailed;
    };

    if (utf16_len > utf16_buf.len) {
        std.debug.print("UTF-16 string too long: {} characters\n", .{utf16_len});
        return HStringError.ConversionFailed;
    }

    var hstring: HSTRING = null;
    const hr = winrt_core.WindowsCreateString(@alignCast(@ptrCast(&utf16_buf[0])), @intCast(utf16_len), &hstring);

    if (hr != S_OK) {
        std.debug.print("WindowsCreateString failed with HRESULT: 0x{X}\n", .{hr});
        return HStringError.CreateStringFailed;
    }

    return hstring;
}

/// Create an HSTRING from a UTF-16 string
pub fn createFromUtf16(utf16_str: []const u16) HStringError!HSTRING {
    var hstring: HSTRING = null;
    const hr = winrt_core.WindowsCreateString(@ptrCast(utf16_str.ptr), @intCast(utf16_str.len), &hstring);

    if (hr != S_OK) {
        std.debug.print("WindowsCreateString failed with HRESULT: 0x{X}\n", .{hr});
        return HStringError.CreateStringFailed;
    }

    return hstring;
}

/// Destroy an HSTRING (release its resources)
pub fn destroy(hstring: HSTRING) void {
    if (hstring) |_| {
        _ = winrt_core.WindowsDeleteString(hstring);
    }
}

/// RAII wrapper for HSTRING
pub const HStringWrapper = struct {
    hstring: HSTRING,

    pub fn init(utf8_str: []const u8) HStringError!HStringWrapper {
        return HStringWrapper{
            .hstring = try create(utf8_str),
        };
    }

    pub fn initFromUtf16(utf16_str: []const u16) HStringError!HStringWrapper {
        return HStringWrapper{
            .hstring = try createFromUtf16(utf16_str),
        };
    }

    pub fn deinit(self: *HStringWrapper) void {
        destroy(self.hstring);
        self.hstring = null;
    }

    pub fn get(self: *const HStringWrapper) HSTRING {
        return self.hstring;
    }
};

/// Batch HSTRING manager for managing multiple HSTRINGs
pub const HStringBatch = struct {
    allocator: std.mem.Allocator,
    hstrings: std.ArrayList(HSTRING),

    pub fn init(allocator: std.mem.Allocator) HStringBatch {
        return HStringBatch{
            .allocator = allocator,
            .hstrings = std.ArrayList(HSTRING).init(allocator),
        };
    }

    pub fn deinit(self: *HStringBatch) void {
        // Clean up all HSTRINGs
        for (self.hstrings.items) |hstring| {
            destroy(hstring);
        }
        self.hstrings.deinit();
    }

    pub fn add(self: *HStringBatch, utf8_str: []const u8) !HSTRING {
        const hstring = try create(utf8_str);
        try self.hstrings.append(hstring);
        return hstring;
    }

    pub fn addUtf16(self: *HStringBatch, utf16_str: []const u16) !HSTRING {
        const hstring = try createFromUtf16(utf16_str);
        try self.hstrings.append(hstring);
        return hstring;
    }
};

// Common WinRT class names as HSTRINGs
pub const WinRTClassNames = struct {
    pub const CORE_APPLICATION = "Windows.ApplicationModel.Core.CoreApplication";
    pub const CALENDAR = "Windows.Globalization.Calendar";
    pub const APPLICATION_VIEW = "Windows.UI.ViewManagement.ApplicationView";
    pub const UI_SETTINGS = "Windows.UI.ViewManagement.UISettings";
};
