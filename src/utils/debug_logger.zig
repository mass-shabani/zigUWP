// src\utils\debug_logger.zig

// سیستم Logging پیشرفته برای UWP در Zig
const std = @import("std");
const windows = std.os.windows;
const WINAPI = windows.WINAPI;

// Windows API declarations
extern "kernel32" fn OutputDebugStringW(lpOutputString: [*:0]const u16) callconv(WINAPI) void;
extern "kernel32" fn GetCurrentProcessId() callconv(WINAPI) u32;
extern "kernel32" fn GetCurrentThreadId() callconv(WINAPI) u32;
extern "kernel32" fn GetLocalTime(lpSystemTime: *SYSTEMTIME) callconv(WINAPI) void;
extern "kernel32" fn CreateFileW(
    lpFileName: [*:0]const u16,
    dwDesiredAccess: u32,
    dwShareMode: u32,
    lpSecurityAttributes: ?*anyopaque,
    dwCreationDisposition: u32,
    dwFlagsAndAttributes: u32,
    hTemplateFile: ?windows.HANDLE,
) callconv(WINAPI) windows.HANDLE;
extern "kernel32" fn WriteFile(
    hFile: windows.HANDLE,
    lpBuffer: [*]const u8,
    nNumberOfBytesToWrite: u32,
    lpNumberOfBytesWritten: ?*u32,
    lpOverlapped: ?*anyopaque,
) callconv(WINAPI) windows.BOOL;
extern "kernel32" fn CloseHandle(hObject: windows.HANDLE) callconv(WINAPI) windows.BOOL;
extern "kernel32" fn ExpandEnvironmentStringsW(
    lpSrc: [*:0]const u16,
    lpDst: [*]u16,
    nSize: u32,
) callconv(WINAPI) u32;

// Constants
const GENERIC_WRITE: u32 = 0x40000000;
const FILE_SHARE_READ: u32 = 0x00000001;
const CREATE_ALWAYS: u32 = 2;
const FILE_ATTRIBUTE_NORMAL: u32 = 0x80;
const INVALID_HANDLE_VALUE = @as(windows.HANDLE, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));

const SYSTEMTIME = extern struct {
    wYear: u16,
    wMonth: u16,
    wDayOfWeek: u16,
    wDay: u16,
    wHour: u16,
    wMinute: u16,
    wSecond: u16,
    wMilliseconds: u16,
};

/// Log Level
pub const LogLevel = enum {
    Debug,
    Info,
    Warning,
    Error,
    Critical,

    pub fn toString(self: LogLevel) []const u8 {
        return switch (self) {
            .Debug => "DEBUG",
            .Info => "INFO",
            .Warning => "WARN",
            .Error => "ERROR",
            .Critical => "CRIT",
        };
    }

    pub fn toColor(self: LogLevel) []const u8 {
        return switch (self) {
            .Debug => "\x1b[36m", // Cyan
            .Info => "\x1b[32m", // Green
            .Warning => "\x1b[33m", // Yellow
            .Error => "\x1b[31m", // Red
            .Critical => "\x1b[35m", // Magenta
        };
    }
};

/// Debug Logger for UWP Applications
pub const DebugLogger = struct {
    allocator: std.mem.Allocator,
    log_file: ?windows.HANDLE,
    pid: u32,
    enable_file: bool,
    enable_debug_output: bool,
    enable_console: bool,

    pub fn init(allocator: std.mem.Allocator) DebugLogger {
        const pid = GetCurrentProcessId();

        var logger = DebugLogger{
            .allocator = allocator,
            .log_file = null,
            .pid = pid,
            .enable_file = true,
            .enable_debug_output = true,
            .enable_console = false, // UWP doesn't have console
        };

        // ایجاد فایل لاگ
        logger.initLogFile() catch {
            // اگر فایل لاگ نتوانست ایجاد شود، فقط از OutputDebugString استفاده می‌کنیم
            // _ = e;
            logger.enable_file = false;
        };

        return logger;
    }

    pub fn deinit(self: *DebugLogger) void {
        if (self.log_file) |handle| {
            _ = CloseHandle(handle);
            self.log_file = null;
        }
    }

    fn initLogFile(self: *DebugLogger) !void {
        // مسیر: %LOCALAPPDATA%\ziguwp_debug.log
        const path_template = "%LOCALAPPDATA%\\ziguwp_debug.log";

        // تبدیل به UTF-16
        var path_utf16: [512]u16 = undefined;
        const template_utf16_len = try std.unicode.utf8ToUtf16Le(&path_utf16, path_template);
        path_utf16[template_utf16_len] = 0;

        // Expand environment variables
        var expanded_path: [1024]u16 = undefined;
        const expanded_len = ExpandEnvironmentStringsW(
            @ptrCast(&path_utf16),
            &expanded_path,
            expanded_path.len,
        );

        if (expanded_len == 0 or expanded_len > expanded_path.len) {
            return error.PathExpansionFailed;
        }

        expanded_path[expanded_len - 1] = 0; // Null terminate

        // ایجاد فایل
        const handle = CreateFileW(
            @ptrCast(&expanded_path),
            GENERIC_WRITE,
            FILE_SHARE_READ,
            null,
            CREATE_ALWAYS,
            FILE_ATTRIBUTE_NORMAL,
            null,
        );

        if (handle == INVALID_HANDLE_VALUE) {
            return error.FileCreationFailed;
        }

        self.log_file = handle;

        // نوشتن هدر
        const header = "========================================\n" ++
            "ZigUWP Debug Log\n" ++
            "========================================\n\n";
        self.writeToFile(header) catch {};
    }

    fn writeToFile(self: *DebugLogger, data: []const u8) !void {
        if (self.log_file) |handle| {
            var bytes_written: u32 = 0;
            const result = WriteFile(
                handle,
                data.ptr,
                @intCast(data.len),
                &bytes_written,
                null,
            );
            if (result == 0) {
                return error.FileWriteFailed;
            }
        }
    }

    fn getCurrentTimestamp(self: *DebugLogger, buffer: []u8) ![]const u8 {
        _ = self;
        var st: SYSTEMTIME = undefined;
        GetLocalTime(&st);

        return std.fmt.bufPrint(
            buffer,
            "[{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}]",
            .{ st.wHour, st.wMinute, st.wSecond, st.wMilliseconds },
        );
    }

    /// Log با سطح مشخص
    pub fn log(
        self: *DebugLogger,
        level: LogLevel,
        comptime fmt: []const u8,
        args: anytype,
    ) void {
        var buffer: [4096]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        var writer = fbs.writer();

        // Timestamp
        var ts_buffer: [32]u8 = undefined;
        const timestamp = self.getCurrentTimestamp(&ts_buffer) catch "[??:??:??.???]";

        // Format message
        writer.print("{s} ", .{timestamp}) catch return;
        writer.print("[PID:{d}] ", .{self.pid}) catch return;
        writer.print("[{s}] ", .{level.toString()}) catch return;
        writer.print(fmt, args) catch return;
        writer.writeByte('\n') catch return;

        const message = fbs.getWritten();

        // Output to Debug Output (DebugView)
        if (self.enable_debug_output) {
            self.outputToDebugString(message);
        }

        // Output to File
        if (self.enable_file) {
            self.writeToFile(message) catch {};
        }
    }

    /// Helper function برای تبدیل و ارسال به OutputDebugStringW
    fn outputToDebugString(self: *DebugLogger, message: []const u8) void {
        _ = self;
        var wide_buffer: [8192]u16 = undefined;

        const wide_len = std.unicode.utf8ToUtf16Le(&wide_buffer, message) catch {
            // اگر تبدیل شکست خورد، پیام خطا بفرست
            const error_msg = "[Logger] UTF-8 to UTF-16 conversion failed\n";
            const error_wide_len = std.unicode.utf8ToUtf16Le(&wide_buffer, error_msg) catch return;
            if (error_wide_len < wide_buffer.len) {
                wide_buffer[error_wide_len] = 0;
                OutputDebugStringW(@ptrCast(&wide_buffer));
            }
            return;
        };

        if (wide_len < wide_buffer.len) {
            wide_buffer[wide_len] = 0;
            OutputDebugStringW(@ptrCast(&wide_buffer));
        }
    }

    /// Shortcut methods
    pub fn debug(self: *DebugLogger, comptime fmt: []const u8, args: anytype) void {
        self.log(.Debug, fmt, args);
    }

    pub fn info(self: *DebugLogger, comptime fmt: []const u8, args: anytype) void {
        self.log(.Info, fmt, args);
    }

    pub fn warn(self: *DebugLogger, comptime fmt: []const u8, args: anytype) void {
        self.log(.Warning, fmt, args);
    }

    pub fn err(self: *DebugLogger, comptime fmt: []const u8, args: anytype) void {
        self.log(.Error, fmt, args);
    }

    pub fn critical(self: *DebugLogger, comptime fmt: []const u8, args: anytype) void {
        self.log(.Critical, fmt, args);
    }

    /// Log برای HRESULT
    pub fn logHRESULT(self: *DebugLogger, level: LogLevel, hr: i32, context: []const u8) void {
        const hr_u32 = @as(u32, @bitCast(hr));
        self.log(level, "HRESULT Error in {s}: 0x{X:0>8}", .{ context, hr_u32 });
    }

    /// Log یک separator
    pub fn separator(self: *DebugLogger, char: u8) void {
        var buffer: [80]u8 = undefined;
        @memset(&buffer, char);
        self.outputToDebugString(&buffer);
        if (self.enable_file) {
            self.writeToFile(&buffer) catch {};
            self.writeToFile("\n") catch {};
        }
    }

    /// Log اطلاعات سیستم
    pub fn logSystemInfo(self: *DebugLogger) void {
        self.separator('=');
        self.info("System Information", .{});
        self.separator('=');

        self.info("Process ID: {d}", .{self.pid});
        self.info("Thread ID: {d}", .{GetCurrentThreadId()});

        // Module path
        var module_path: [1024]u16 = undefined;
        const len = windows.kernel32.GetModuleFileNameW(null, &module_path, module_path.len);
        if (len > 0 and len < module_path.len) {
            module_path[len] = 0;
            // تبدیل به UTF-8 برای نمایش
            var utf8_buffer: [2048]u8 = undefined;
            const utf8_len = std.unicode.utf16LeToUtf8(&utf8_buffer, module_path[0..len]) catch 0;
            if (utf8_len > 0) {
                self.info("Module: {s}", .{utf8_buffer[0..utf8_len]});
            }
        }

        self.separator('-');
    }
};

// Global logger instance
var global_logger: ?*DebugLogger = null;

/// Initialize global logger
pub fn initGlobalLogger(allocator: std.mem.Allocator) !void {
    if (global_logger != null) {
        return error.LoggerAlreadyInitialized;
    }

    const logger = try allocator.create(DebugLogger);
    logger.* = DebugLogger.init(allocator);
    global_logger = logger;

    logger.separator('=');
    logger.info("Global Logger Initialized", .{});
    logger.separator('=');
}

/// Deinitialize global logger
pub fn deinitGlobalLogger(allocator: std.mem.Allocator) void {
    if (global_logger) |logger| {
        logger.separator('=');
        logger.info("Global Logger Shutting Down", .{});
        logger.separator('=');

        logger.deinit();
        allocator.destroy(logger);
        global_logger = null;
    }
}

/// Get global logger
pub fn getLogger() ?*DebugLogger {
    return global_logger;
}

// Convenience functions
pub fn debug(comptime fmt: []const u8, args: anytype) void {
    if (getLogger()) |logger| {
        logger.debug(fmt, args);
    }
}

pub fn info(comptime fmt: []const u8, args: anytype) void {
    if (getLogger()) |logger| {
        logger.info(fmt, args);
    }
}

pub fn warn(comptime fmt: []const u8, args: anytype) void {
    if (getLogger()) |logger| {
        logger.warn(fmt, args);
    }
}

pub fn err(comptime fmt: []const u8, args: anytype) void {
    if (getLogger()) |logger| {
        logger.err(fmt, args);
    }
}

pub fn critical(comptime fmt: []const u8, args: anytype) void {
    if (getLogger()) |logger| {
        logger.critical(fmt, args);
    }
}

pub fn logHRESULT(hr: i32, context: []const u8) void {
    if (getLogger()) |logger| {
        logger.logHRESULT(.Error, hr, context);
    }
}

pub fn separator(char: u8) void {
    if (getLogger()) |logger| {
        logger.separator(char);
    }
}
