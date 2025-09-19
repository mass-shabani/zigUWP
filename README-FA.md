# راهنمای کامل پروژه ZigUWP

## مقدمه

پروژه ZigUWP یک پیاده‌سازی حرفه‌ای و ماژولار از یک UWP Application است که کاملاً با زبان Zig و استفاده از WinRT APIs خالص نوشته شده است. این پروژه بدون هیچ وابستگی به Win32 APIs طراحی شده تا روی تمام دستگاه‌های سازگار با WinRT اجرا شود.

## ساختار کلی پروژه

```
zigUWP/
├── Libs/                          # کتابخانه‌های Windows SDK
├── src/                           # کدهای اصلی پروژه
│   ├── main.zig                   # نقطه ورود برنامه
│   ├── core/                      # هسته WinRT
│   ├── interfaces/                # تعاریف Interface ها
│   ├── implementation/            # پیاده‌سازی کاستوم
│   ├── ui/                        # بخش رابط کاربری
│   └── utils/                     # ابزارهای کمکی
├── build.zig                      # پیکربندی build system
├── Package.appxmanifest           # Manifest برنامه UWP
└── README.md                      # مستندات اصلی
```

## بخش اول: هسته سیستم (Core)

### 1. فایل `winrt_core.zig`

این فایل پایه و اساس کل سیستم WinRT است:

```zig
// ثوابت اصلی WinRT
pub const S_OK: HRESULT = 0;           // موفقیت
pub const E_FAIL: u32 = 0x80004005;    // شکست عمومی

// انواع داده اصلی
pub const HSTRING = ?*anyopaque;       // رشته WinRT
pub const HRESULT = i32;               // کد بازگشت عملیات
```

**مسئولیت‌ها:**
- تعریف ثوابت و انواع داده WinRT
- Declaration توابع خارجی (External Functions)
- ابزارهای کمکی برای کار با HRESULT
- مدیریت حالات موفقیت و شکست عملیات

**توابع مهم:**
```zig
pub fn isSuccess(hr: HRESULT) bool     // بررسی موفقیت عملیات
pub fn isFailure(hr: HRESULT) bool     // بررسی شکست عملیات
pub fn hrToError(hr: HRESULT) anyerror // تبدیل HRESULT به خطا
```

### 2. فایل `com_base.zig`

این فایل اساس کار با COM Objects را فراهم می‌کند:

```zig
// Interface پایه COM
pub const IUnknown = extern struct {
    vtbl: *const IUnknownVtbl,
    
    // توابع اصلی COM
    pub fn addRef(self: *IUnknown) u32
    pub fn release(self: *IUnknown) u32
    pub fn queryInterface(self: *IUnknown, riid: *const GUID, ppvObject: *?*anyopaque) HRESULT
};
```

**ویژگی‌های کلیدی:**
- پیاده‌سازی IUnknown و IInspectable
- مدیریت Reference Counting
- Query Interface برای تبدیل Interface ها
- Helper functions برای COM Objects

**کلاس کمکی:**
```zig
pub const ComObjectBase = struct {
    ref_count: u32,              // شمارنده مراجع
    allocator: std.mem.Allocator, // مدیر حافظه
    
    pub fn addRef(self: *ComObjectBase) u32
    pub fn release(self: *ComObjectBase) u32
};
```

### 3. فایل `activation.zig`

این فایل سیستم فعال‌سازی WinRT را مدیریت می‌کند:

```zig
// مدیر کارخانه فعال‌سازی
pub const ActivationFactoryManager = struct {
    allocator: std.mem.Allocator,
    
    // دریافت کارخانه فعال‌سازی
    pub fn getActivationFactory(class_name: []const u8, iid: *const GUID) !*anyopaque
    
    // ایجاد instance از کلاس WinRT
    pub fn createInstance(class_name: []const u8, instance_iid: *const GUID) !*anyopaque
};
```

**مدیر سیستم WinRT:**
```zig
pub const WinRTSystem = struct {
    is_initialized: bool,
    com_initialized: bool,
    
    pub fn startup(self: *WinRTSystem) !void    // راه‌اندازی
    pub fn shutdown(self: *WinRTSystem) void    // خاموش کردن
};
```

## بخش دوم: تعاریف Interface ها

### 1. فایل `application.zig`

تعریف Interface های مربوط به برنامه اصلی:

```zig
// Interface اصلی برنامه
pub const ICoreApplication = extern struct {
    vtbl: *const ICoreApplicationVtbl,
    
    pub fn run(self: *ICoreApplication, view_source: *IFrameworkViewSource) HRESULT
    pub fn getCurrentView(self: *ICoreApplication, view: *?*ICoreApplicationView) HRESULT
};

// مدیر برنامه اصلی
pub const CoreApplicationManager = struct {
    core_application: ?*ICoreApplication,
    
    pub fn getCoreApplication(self: *CoreApplicationManager) !*ICoreApplication
};
```

### 2. فایل `view.zig`

Interface های مربوط به View ها:

```zig
// کارخانه ایجاد View
pub const IFrameworkViewSource = extern struct {
    vtbl: *const IFrameworkViewSourceVtbl,
    
    pub fn createView(self: *IFrameworkViewSource, view: *?*IFrameworkView) HRESULT
};

// View اصلی برنامه
pub const IFrameworkView = extern struct {
    vtbl: *const IFrameworkViewVtbl,
    
    pub fn initialize(self: *IFrameworkView, app_view: *ICoreApplicationView) HRESULT
    pub fn setWindow(self: *IFrameworkView, window: *ICoreWindow) HRESULT
    pub fn load(self: *IFrameworkView, entryPoint: HSTRING) HRESULT
    pub fn run(self: *IFrameworkView) HRESULT
    pub fn uninitialize(self: *IFrameworkView) HRESULT
};
```

### 3. فایل `window.zig`

Interface های مربوط به پنجره:

```zig
// پنجره اصلی
pub const ICoreWindow = extern struct {
    vtbl: *const ICoreWindowVtbl,
    
    pub fn activate(self: *ICoreWindow) HRESULT
    pub fn getDispatcher(self: *ICoreWindow, dispatcher: *?*ICoreDispatcher) HRESULT
    pub fn getVisible(self: *ICoreWindow, visible: *bool) HRESULT
};

// مدیر رویدادها
pub const ICoreDispatcher = extern struct {
    vtbl: *const ICoreDispatcherVtbl,
    
    pub fn processEvents(self: *ICoreDispatcher, options: CoreProcessEventsOption) HRESULT
};
```

## بخش سوم: پیاده‌سازی کاستوم

### 1. فایل `framework_view.zig`

پیاده‌سازی کاستوم IFrameworkView:

```zig
pub const UWPFrameworkView = extern struct {
    vtbl: *const IFrameworkViewVtbl,
    base: com_base.ComObjectBase,
    
    // وضعیت برنامه
    app_view: ?*ICoreApplicationView,
    core_window: ?*ICoreWindow,
    window_manager: ?*WindowManager,
    error_handler: ?*ErrorHandler,
    
    // ایجاد instance جدید
    pub fn create(allocator: std.mem.Allocator) !*Self
    
    // نابودی و تمیز کردن
    pub fn destroy(self: *Self) void
};
```

**مراحل اجرا:**
1. `Initialize` - مقداردهی اولیه
2. `SetWindow` - تنظیم پنجره
3. `Load` - بارگذاری منابع
4. `Run` - اجرای حلقه اصلی
5. `Uninitialize` - تمیز کردن

### 2. فایل `view_source.zig`

کارخانه ایجاد View ها:

```zig
pub const UWPFrameworkViewSource = extern struct {
    vtbl: *const IFrameworkViewSourceVtbl,
    base: com_base.ComObjectBase,
    
    // ایجاد View جدید
    fn createView(self: *IFrameworkViewSource, view: *?*IFrameworkView) HRESULT {
        const framework_view_instance = UWPFrameworkView.create(allocator);
        view.* = @ptrCast(framework_view_instance);
        return S_OK;
    }
};
```

## بخش چهارم: ابزارهای کمکی

### 1. فایل `hstring.zig`

مدیریت رشته‌های WinRT:

```zig
// ایجاد HSTRING از UTF-8
pub fn create(utf8_str: []const u8) !HSTRING

// نابودی HSTRING
pub fn destroy(hstring: HSTRING) void

// Wrapper با RAII
pub const HStringWrapper = struct {
    hstring: HSTRING,
    
    pub fn init(utf8_str: []const u8) !HStringWrapper
    pub fn deinit(self: *HStringWrapper) void
};

// مدیریت دسته‌ای
pub const HStringBatch = struct {
    hstrings: std.ArrayList(HSTRING),
    
    pub fn add(self: *HStringBatch, utf8_str: []const u8) !HSTRING
    pub fn deinit(self: *HStringBatch) void
};
```

### 2. فایل `error_handling.zig`

سیستم مدیریت خطا:

```zig
// انواع خطای UWP
pub const UWPError = error{
    ComInitializationFailed,
    WinRTInitializationFailed,
    ApplicationStartupFailed,
    ViewCreationFailed,
    // ...
};

// زمینه خطا برای debugging
pub const ErrorContext = struct {
    error_code: HRESULT,
    operation: []const u8,
    component: []const u8,
    
    pub fn print(self: *const ErrorContext) void  // چاپ جزئیات خطا
};

// مدیر خطا
pub const ErrorHandler = struct {
    error_history: std.ArrayList(ErrorContext),
    
    pub fn handleError(self: *ErrorHandler, error_context: ErrorContext) UWPError
    pub fn printErrorHistory(self: *ErrorHandler) void
};
```

## بخش پنجم: برنامه اصلی

### فایل `main.zig`

```zig
const UWPApplication = struct {
    allocator: std.mem.Allocator,
    winrt_system: WinRTSystem,
    core_app_manager: CoreApplicationManager,
    error_handler: ErrorHandler,
    view_source: ?*UWPFrameworkViewSource,
    
    pub fn startup(self: *UWPApplication) !void {
        // راه‌اندازی WinRT
        try self.winrt_system.startup();
    }
    
    pub fn createViewSource(self: *UWPApplication) !void {
        // ایجاد ViewSource
        self.view_source = try UWPFrameworkViewSource.create(self.allocator);
    }
    
    pub fn run(self: *UWPApplication) !void {
        // اجرای برنامه
        const core_app = try self.core_app_manager.getCoreApplication();
        const hr = core_app.run(@ptrCast(self.view_source.?));
        // ...
    }
};
```

## نحوه Build و اجرا

### پیش‌نیازها:

1. **نصب Zig 0.14.1** یا جدیدتر
2. **Windows 10 SDK** (10.0.17763.0 یا جدیدتر)
3. **فعال کردن Developer Mode** در Windows Settings

### کپی کتابخانه‌ها:

از مسیر SDK به پوشه `Libs/` کپی کنید:
```
ole32.lib          # از um\x64\
windowsapp.lib     # از winrt\x64\
runtimeobject.lib  # از winrt\x64\
```

### دستورات Build:

```bash
# برنامه اصلی UWP
zig build run

# تست عملکرد WinRT
zig build test-winrt

# تست ماژول‌ها
zig build test-modules

# تست واحد
zig build test

# ایجاد مستندات
zig build docs

# نمایش راهنما
zig build help
```

## نکات توسعه

### اضافه کردن ماژول جدید:

1. فایل جدید در پوشه مناسب بسازید
2. الگوی COM interface را دنبال کنید
3. Error handling مناسب اضافه کنید
4. تست واحد بنویسید
5. build.zig را به‌روزرسانی کنید

### الگوی پیاده‌سازی COM:

```zig
pub const IMyInterface = extern struct {
    vtbl: *const IMyInterfaceVtbl,
    
    pub const IMyInterfaceVtbl = extern struct {
        // IUnknown methods
        QueryInterface: *const fn(...) callconv(WINAPI) HRESULT,
        AddRef: *const fn(...) callconv(WINAPI) u32,
        Release: *const fn(...) callconv(WINAPI) u32,
        
        // IInspectable methods (در صورت نیاز)
        GetIids: *const fn(...) callconv(WINAPI) HRESULT,
        GetRuntimeClassName: *const fn(...) callconv(WINAPI) HRESULT,
        GetTrustLevel: *const fn(...) callconv(WINAPI) HRESULT,
        
        // متدهای اختصاصی interface
        MyMethod: *const fn(...) callconv(WINAPI) HRESULT,
    };
    
    // توابع کمکی
    pub fn myMethod(self: *IMyInterface, ...) HRESULT {
        return self.vtbl.MyMethod(self, ...);
    }
};
```

## عیب‌یابی رایج

### مشکل: `RoInitialize failed: 0x1`
**راه‌حل:** این کد S_FALSE است و طبیعی است (WinRT قبلاً initialize شده).

### مشکل: پنجره نمایش داده نمی‌شود
**راه‌حل‌ها:**
- Developer Mode را فعال کنید
- از Developer Command Prompt اجرا کنید
- Windows 10+ داشته باشید
- نیازمندی‌های UWP deployment را بررسی کنید

### مشکل: خطای Library linking
**راه‌حل:** همه فایل‌های `.lib` را با architecture درست در `Libs/` قرار دهید.

## توسعه آینده

این architecture قابلیت توسعه برای موارد زیر را دارد:

- **XAML UI**: اضافه کردن interface های XAML
- **API های اضافی**: WinRT API های جدید
- **کنترل‌های سفارشی**: UI components اختصاصی
- **Storage APIs**: مدیریت فایل و داده
- **Networking**: HTTP/Socket wrappers
- **Graphics**: Direct2D/Direct3D integration

## نتیجه‌گیری

این پروژه نمونه‌ای کامل از توسعه UWP حرفه‌ای با Zig است که:

- architecture ماژولار و قابل نگهداری دارد
- مدیریت خطای جامع ارائه می‌دهد
- memory safety را تضمین می‌کند
- روی تمام دستگاه‌های WinRT سازگار است
- قابلیت توسعه برای پروژه‌های واقعی را دارد

این ساختار الگویی برای توسعه نرم‌افزارهای UWP در Zig فراهم می‌کند که اصول مهندسی نرم‌افزار مدرن را رعایت می‌کند.