const std = @import("std");
const windows = std.os.windows;

// Re-export Windows types for convenience
pub const WINAPI = windows.WINAPI;
pub const HRESULT = windows.HRESULT;
pub const GUID = windows.GUID;
pub const LPCWSTR = windows.LPCWSTR;

// WinRT Constants
pub const S_OK: HRESULT = 0;
pub const S_FALSE: HRESULT = 1;
pub const E_FAIL: u32 = 0x80004005;
pub const E_NOINTERFACE: u32 = 0x80004002;
pub const RPC_E_CHANGED_MODE: u32 = 0x80010106;

// COM/WinRT Initialization
pub const COINIT_APARTMENTTHREADED: u32 = 0x2;
pub const RO_INIT_SINGLETHREADED: u32 = 0;
pub const RO_INIT_MULTITHREADED: u32 = 1;

// Trust Level enumeration
pub const TrustLevel = enum(i32) {
    BaseTrust = 0,
    PartialTrust = 1,
    FullTrust = 2,
};

// Core WinRT types
pub const HSTRING = ?*anyopaque;

pub const EventRegistrationToken = extern struct {
    value: i64,
};

// Application execution states
pub const ApplicationExecutionState = enum(i32) {
    NotRunning = 0,
    Running = 1,
    Suspended = 2,
    Terminated = 3,
    ClosedByUser = 4,
};

// Core dispatcher priorities
pub const CoreDispatcherPriority = enum(i32) {
    Idle = -2,
    Low = -1,
    Normal = 0,
    High = 1,
};

// Process events options
pub const CoreProcessEventsOption = enum(u32) {
    ProcessOneAndAllPending = 0,
    ProcessOneIfPresent = 1,
    ProcessUntilQuit = 2,
    ProcessAllIfPresent = 3,
};

// External WinRT API functions
pub extern "ole32" fn CoInitializeEx(pvReserved: ?*anyopaque, dwCoInit: u32) callconv(WINAPI) HRESULT;

pub extern "ole32" fn CoUninitialize() callconv(WINAPI) void;

pub extern "windowsapp" fn WindowsCreateString(sourceString: LPCWSTR, length: u32, string: *HSTRING) callconv(WINAPI) HRESULT;

pub extern "windowsapp" fn WindowsDeleteString(string: HSTRING) callconv(WINAPI) HRESULT;

pub extern "windowsapp" fn RoGetActivationFactory(activatableClassId: HSTRING, iid: *const GUID, factory: *?*anyopaque) callconv(WINAPI) HRESULT;

pub extern "windowsapp" fn RoInitialize(initType: u32) callconv(WINAPI) HRESULT;

pub extern "windowsapp" fn RoUninitialize() callconv(WINAPI) void;

// Utility functions for error handling
pub fn isSuccess(hr: HRESULT) bool {
    return hr >= 0;
}

pub fn isFailure(hr: HRESULT) bool {
    return hr < 0;
}

pub fn hrToError(hr: HRESULT) anyerror {
    return switch (@as(u32, @bitCast(hr))) {
        E_FAIL => error.GeneralFailure,
        E_NOINTERFACE => error.NoInterface,
        RPC_E_CHANGED_MODE => error.ChangedMode,
        else => error.UnknownHRESULT,
    };
}
