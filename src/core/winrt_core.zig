// src/core/winrt_core.zig
// Core WinRT types and function declarations
// This is the foundation layer - no business logic, only type definitions

const std = @import("std");
const windows = std.os.windows;

// ============================================================================
// Type Re-exports from Windows
// ============================================================================

pub const WINAPI = windows.WINAPI;
pub const HRESULT = windows.HRESULT;
pub const GUID = windows.GUID;
pub const BOOL = windows.BOOL;
pub const HWND = windows.HWND;
pub const HANDLE = windows.HANDLE;

// ============================================================================
// WinRT String Types
// ============================================================================

pub const HSTRING = ?*opaque {};
pub const LPCWSTR = [*:0]const u16;
pub const LPWSTR = [*:0]u16;

// ============================================================================
// HRESULT Constants
// ============================================================================

// Success codes
pub const S_OK: HRESULT = 0;
pub const S_FALSE: HRESULT = 1;

// Common error codes
pub const E_NOTIMPL: u32 = 0x80004001;
pub const E_NOINTERFACE: u32 = 0x80004002;
pub const E_POINTER: u32 = 0x80004003;
pub const E_ABORT: u32 = 0x80004004;
pub const E_FAIL: u32 = 0x80004005;
pub const E_UNEXPECTED: u32 = 0x8000FFFF;
pub const E_ACCESSDENIED: u32 = 0x80070005;
pub const E_HANDLE: u32 = 0x80070006;
pub const E_OUTOFMEMORY: u32 = 0x8007000E;
pub const E_INVALIDARG: u32 = 0x80070057;

// COM specific
pub const CO_E_NOTINITIALIZED: u32 = 0x800401F0;
pub const RPC_E_CHANGED_MODE: u32 = 0x80010106;
pub const REGDB_E_CLASSNOTREG: u32 = 0x80040154;

// ============================================================================
// COM Initialization
// ============================================================================

pub const COINIT_APARTMENTTHREADED: u32 = 0x2;
pub const COINIT_MULTITHREADED: u32 = 0x0;
pub const COINIT_DISABLE_OLE1DDE: u32 = 0x4;
pub const COINIT_SPEED_OVER_MEMORY: u32 = 0x8;

// ============================================================================
// WinRT Initialization
// ============================================================================

pub const RO_INIT_SINGLETHREADED: u32 = 0;
pub const RO_INIT_MULTITHREADED: u32 = 1;

pub const RO_REGISTRATION_COOKIE = usize;

// ============================================================================
// Trust Level
// ============================================================================

pub const TrustLevel = enum(i32) {
    BaseTrust = 0,
    PartialTrust = 1,
    FullTrust = 2,
};

// ============================================================================
// Event Registration
// ============================================================================

pub const EventRegistrationToken = extern struct {
    value: i64,
};

// ============================================================================
// Application State
// ============================================================================

pub const ApplicationExecutionState = enum(i32) {
    NotRunning = 0,
    Running = 1,
    Suspended = 2,
    Terminated = 3,
    ClosedByUser = 4,
};

// ============================================================================
// Dispatcher
// ============================================================================

pub const CoreDispatcherPriority = enum(i32) {
    Idle = -2,
    Low = -1,
    Normal = 0,
    High = 1,
};

pub const CoreProcessEventsOption = enum(u32) {
    ProcessOneAndAllPending = 0,
    ProcessOneIfPresent = 1,
    ProcessUntilQuit = 2,
    ProcessAllIfPresent = 3,
};

// ============================================================================
// XAML Types (for future use)
// ============================================================================

pub const XamlSourceFocusNavigationReason = enum(i32) {
    Programmatic = 0,
    Restore = 1,
    First = 3,
    Last = 4,
    Left = 7,
    Up = 8,
    Right = 9,
    Down = 10,
};

// ============================================================================
// External Function Declarations - combase.dll
// ============================================================================

pub extern "combase" fn CoInitializeEx(
    pvReserved: ?*anyopaque,
    dwCoInit: u32,
) callconv(WINAPI) HRESULT;

pub extern "combase" fn CoUninitialize() callconv(WINAPI) void;

pub extern "combase" fn CoCreateInstance(
    rclsid: *const GUID,
    pUnkOuter: ?*anyopaque,
    dwClsContext: u32,
    riid: *const GUID,
    ppv: *?*anyopaque,
) callconv(WINAPI) HRESULT;

// ============================================================================
// External Function Declarations - WindowsApp.lib (WinRT)
// ============================================================================

pub extern "windowsapp" fn RoInitialize(
    initType: u32,
) callconv(WINAPI) HRESULT;

pub extern "windowsapp" fn RoUninitialize() callconv(WINAPI) void;

pub extern "windowsapp" fn RoGetActivationFactory(
    activatableClassId: HSTRING,
    iid: *const GUID,
    factory: *?*anyopaque,
) callconv(WINAPI) HRESULT;

pub extern "windowsapp" fn RoActivateInstance(
    activatableClassId: HSTRING,
    instance: *?*anyopaque,
) callconv(WINAPI) HRESULT;

pub extern "windowsapp" fn RoRegisterActivationFactories(
    activatableClassIds: [*]const HSTRING,
    activationFactoryCallbacks: [*]const *anyopaque,
    count: u32,
    cookie: *RO_REGISTRATION_COOKIE,
) callconv(WINAPI) HRESULT;

pub extern "windowsapp" fn RoRevokeActivationFactories(
    cookie: RO_REGISTRATION_COOKIE,
) callconv(WINAPI) void;

// ============================================================================
// External Function Declarations - HSTRING Management
// ============================================================================

pub extern "windowsapp" fn WindowsCreateString(
    sourceString: LPCWSTR,
    length: u32,
    string: *HSTRING,
) callconv(WINAPI) HRESULT;

pub extern "windowsapp" fn WindowsCreateStringReference(
    sourceString: LPCWSTR,
    length: u32,
    hstringHeader: *HSTRING_HEADER,
    string: *HSTRING,
) callconv(WINAPI) HRESULT;

pub extern "windowsapp" fn WindowsDeleteString(
    string: HSTRING,
) callconv(WINAPI) HRESULT;

pub extern "windowsapp" fn WindowsDuplicateString(
    string: HSTRING,
    newString: *HSTRING,
) callconv(WINAPI) HRESULT;

pub extern "windowsapp" fn WindowsGetStringLen(
    string: HSTRING,
) callconv(WINAPI) u32;

pub extern "windowsapp" fn WindowsGetStringRawBuffer(
    string: HSTRING,
    length: ?*u32,
) callconv(WINAPI) LPCWSTR;

pub extern "windowsapp" fn WindowsIsStringEmpty(
    string: HSTRING,
) callconv(WINAPI) BOOL;

pub extern "windowsapp" fn WindowsStringHasEmbeddedNull(
    string: HSTRING,
    hasEmbedNull: *BOOL,
) callconv(WINAPI) HRESULT;

pub extern "windowsapp" fn WindowsCompareStringOrdinal(
    string1: HSTRING,
    string2: HSTRING,
    result: *i32,
) callconv(WINAPI) HRESULT;

pub extern "windowsapp" fn WindowsSubstring(
    string: HSTRING,
    startIndex: u32,
    newString: *HSTRING,
) callconv(WINAPI) HRESULT;

pub extern "windowsapp" fn WindowsSubstringWithSpecifiedLength(
    string: HSTRING,
    startIndex: u32,
    length: u32,
    newString: *HSTRING,
) callconv(WINAPI) HRESULT;

pub extern "windowsapp" fn WindowsConcatString(
    string1: HSTRING,
    string2: HSTRING,
    newString: *HSTRING,
) callconv(WINAPI) HRESULT;

// HSTRING header for fast string creation
pub const HSTRING_HEADER = extern struct {
    flags: u32,
    length: u32,
    padding1: u32,
    padding2: u32,
    data: ?*anyopaque,
};

// ============================================================================
// Utility Functions
// ============================================================================

/// Check if HRESULT indicates success
pub inline fn SUCCEEDED(hr: HRESULT) bool {
    return hr >= 0;
}

/// Check if HRESULT indicates failure
pub inline fn FAILED(hr: HRESULT) bool {
    return hr < 0;
}

/// Legacy aliases for compatibility
pub const isSuccess = SUCCEEDED;
pub const isFailure = FAILED;

/// Convert HRESULT to Zig error
pub fn hrToError(hr: HRESULT) anyerror {
    const hr_u32 = @as(u32, @bitCast(hr));
    return switch (hr_u32) {
        E_NOTIMPL => error.NotImplemented,
        E_NOINTERFACE => error.NoInterface,
        E_POINTER => error.NullPointer,
        E_ABORT => error.OperationAborted,
        E_FAIL => error.GeneralFailure,
        E_UNEXPECTED => error.UnexpectedError,
        E_ACCESSDENIED => error.AccessDenied,
        E_HANDLE => error.InvalidHandle,
        E_OUTOFMEMORY => error.OutOfMemory,
        E_INVALIDARG => error.InvalidArgument,
        CO_E_NOTINITIALIZED => error.NotInitialized,
        RPC_E_CHANGED_MODE => error.ChangedMode,
        REGDB_E_CLASSNOTREG => error.ClassNotRegistered,
        else => error.UnknownHRESULT,
    };
}

/// Get HRESULT code from u32
pub inline fn HRESULT_FROM_WIN32(x: u32) HRESULT {
    return @bitCast(if (x <= 0) x else ((x & 0x0000FFFF) | 0x80070000));
}

/// Get HRESULT facility
pub inline fn HRESULT_FACILITY(hr: HRESULT) u16 {
    const hr_u32 = @as(u32, @bitCast(hr));
    return @intCast((hr_u32 >> 16) & 0x1FFF);
}

/// Get HRESULT code
pub inline fn HRESULT_CODE(hr: HRESULT) u16 {
    const hr_u32 = @as(u32, @bitCast(hr));
    return @intCast(hr_u32 & 0xFFFF);
}

// ============================================================================
// GUID Utilities
// ============================================================================

/// Compare two GUIDs
pub fn guidEqual(a: *const GUID, b: *const GUID) bool {
    return std.mem.eql(u8, std.mem.asBytes(a), std.mem.asBytes(b));
}

/// Create GUID from components
pub fn makeGUID(
    data1: u32,
    data2: u16,
    data3: u16,
    data4: [8]u8,
) GUID {
    return GUID{
        .Data1 = data1,
        .Data2 = data2,
        .Data3 = data3,
        .Data4 = data4,
    };
}

// ============================================================================
// Debug Helpers
// ============================================================================

/// Format HRESULT for debugging
pub fn formatHRESULT(hr: HRESULT, buffer: []u8) ![]const u8 {
    const hr_u32 = @as(u32, @bitCast(hr));
    return std.fmt.bufPrint(buffer, "0x{X:0>8}", .{hr_u32});
}

/// Get HRESULT description
pub fn getHRESULTDescription(hr: HRESULT) []const u8 {
    const hr_u32 = @as(u32, @bitCast(hr));
    return switch (hr_u32) {
        0 => "S_OK",
        1 => "S_FALSE",
        E_NOTIMPL => "E_NOTIMPL",
        E_NOINTERFACE => "E_NOINTERFACE",
        E_POINTER => "E_POINTER",
        E_ABORT => "E_ABORT",
        E_FAIL => "E_FAIL",
        E_UNEXPECTED => "E_UNEXPECTED",
        E_ACCESSDENIED => "E_ACCESSDENIED",
        E_HANDLE => "E_HANDLE",
        E_OUTOFMEMORY => "E_OUTOFMEMORY",
        E_INVALIDARG => "E_INVALIDARG",
        CO_E_NOTINITIALIZED => "CO_E_NOTINITIALIZED",
        RPC_E_CHANGED_MODE => "RPC_E_CHANGED_MODE",
        REGDB_E_CLASSNOTREG => "REGDB_E_CLASSNOTREG",
        else => "Unknown HRESULT",
    };
}
