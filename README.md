**⚠️ Warning:** This project is being used as a research effort within a larger project and is not yet a usable product. It is newly created and currently under development.



# ZigUWP - Pure WinRT UWP Application

A professional, modular UWP (Universal Windows Platform) application implementation written entirely in Zig, using pure WinRT APIs without Win32 dependencies for maximum device compatibility.

## 🏗️ Architecture Overview

This project demonstrates a clean, modular architecture for WinRT development in Zig:

```
zigUWP/
├── Libs/                          # Windows SDK libraries
│   └── README.md                  # Library setup instructions
├── src/
│   ├── main.zig                   # Application entry point
│   ├── core/                      # Core WinRT functionality
│   │   ├── winrt_core.zig        # Core WinRT definitions & utilities
│   │   ├── com_base.zig          # COM fundamentals & helpers
│   │   └── activation.zig        # Activation factories & system management
│   ├── interfaces/                # WinRT interface definitions
│   │   ├── application.zig       # Core Application interfaces
│   │   ├── view.zig              # Framework View interfaces  
│   │   └── window.zig            # Core Window interfaces
│   ├── implementation/            # Custom implementations
│   │   ├── framework_view.zig    # FrameworkView implementation
│   │   └── view_source.zig       # FrameworkViewSource implementation
│   ├── ui/                       # UI-related functionality (extensible)
│   │   └── xaml.zig              # XAML interfaces (future)
│   └── utils/                    # Utility modules
│       ├── hstring.zig           # HSTRING management utilities
│       └── error_handling.zig    # Professional error handling
├── build.zig                     # Build system configuration
├── Package.appxmanifest          # UWP application manifest
└── README.md                     # This file
```

## 🚀 Features

### Core Capabilities
- **Pure WinRT Implementation**: No Win32 dependencies for UI components
- **Cross-Device Compatibility**: Runs on all WinRT-compatible devices
- **Professional Architecture**: Modular, maintainable, and extensible design
- **Memory Safety**: Proper COM object lifecycle management
- **Error Handling**: Comprehensive error tracking and debugging

### Technical Highlights
- **Modular Design**: Clean separation of concerns across modules
- **COM Integration**: Full COM/WinRT interface implementations
- **RAII Patterns**: Automatic resource management with Zig's defer
- **Type Safety**: Leverages Zig's compile-time safety guarantees
- **Professional Logging**: Detailed debugging and error reporting

## 🛠️ Prerequisites

### Required Software
1. **Zig 0.14.1** or newer
2. **Windows 10 SDK** (10.0.17763.0 or newer)
3. **Developer Mode** enabled in Windows Settings

### Required Libraries
Copy the following libraries from your Windows SDK installation to the `Libs/` directory:

```bash
# From Windows SDK (e.g., C:\Program Files (x86)\Windows Kits\10\Lib\{version}\)
Libs/
├── ole32.lib          # COM support
├── windowsapp.lib     # WinRT runtime
└── runtimeobject.lib  # WinRT runtime objects
```

**SDK Path Examples:**
- `C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\um\x64\ole32.lib`
- `C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\winrt\x64\windowsapp.lib`
- `C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\winrt\x64\runtimeobject.lib`

## 🏃‍♂️ Quick Start

### 1. Build and Run
```bash
# Main UWP application
zig build run

# Test WinRT functionality
zig build test-winrt

# Test individual modules
zig build test-modules

# Run unit tests
zig build test
```

### 2. Available Commands
```bash
zig build run           # Run main UWP application
zig build test-winrt    # Test basic WinRT functionality  
zig build run-hybrid    # Run hybrid Win32+WinRT demo (comparison)
zig build test-modules  # Test individual modules
zig build test          # Run unit tests
zig build docs          # Generate documentation
zig build clean         # Clean build artifacts
zig build help          # Show all commands
```

## 📋 Module Breakdown

### Core Modules (`src/core/`)

#### `winrt_core.zig`
- WinRT constants and types
- HRESULT utilities
- External API declarations
- Core system functions

#### `com_base.zig` 
- COM fundamentals (IUnknown, IInspectable)
- Reference counting helpers
- Interface query utilities
- COM object base implementation

#### `activation.zig`
- WinRT activation factory management
- System initialization/shutdown
- Factory creation and instance management

### Interface Definitions (`src/interfaces/`)

#### `application.zig`
- `ICoreApplication` interface
- `ICoreApplicationView` interface  
- Application lifecycle management

#### `view.zig`
- `IFrameworkView` interface
- `IFrameworkViewSource` interface
- View lifecycle management

#### `window.zig`
- `ICoreWindow` interface
- `ICoreDispatcher` interface
- Window and event management

### Custom Implementations (`src/implementation/`)

#### `framework_view.zig`
- Custom `IFrameworkView` implementation
- Application lifecycle handling
- Window management integration

#### `view_source.zig`
- Custom `IFrameworkViewSource` implementation  
- View creation factory

### Utilities (`src/utils/`)

#### `hstring.zig`
- HSTRING creation/destruction
- UTF-8 to UTF-16 conversion
- RAII wrapper classes
- Batch management utilities

#### `error_handling.zig`
- Comprehensive error types
- HRESULT to error mapping
- Error context tracking
- Professional logging system

## 🔧 Development Guidelines

### Adding New Modules
1. Create module in appropriate directory (`core/`, `interfaces/`, etc.)
2. Follow established patterns for COM interfaces
3. Add proper error handling
4. Include unit tests in `test_modules.zig`
5. Update build.zig if needed

### COM Interface Implementation
```zig
// Example pattern for new COM interfaces
pub const IMyInterface = extern struct {
    vtbl: *const IMyInterfaceVtbl,
    
    pub const IMyInterfaceVtbl = extern struct {
        // IUnknown methods first
        QueryInterface: *const fn(...) callconv(WINAPI) HRESULT,
        AddRef: *const fn(...) callconv(WINAPI) u32,
        Release: *const fn(...) callconv(WINAPI) u32,
        
        // IInspectable methods (if applicable)
        GetIids: *const fn(...) callconv(WINAPI) HRESULT,
        GetRuntimeClassName: *const fn(...) callconv(WINAPI) HRESULT,
        GetTrustLevel: *const fn(...) callconv(WINAPI) HRESULT,
        
        // Interface-specific methods
        MyMethod: *const fn(...) callconv(WINAPI) HRESULT,
    };
    
    // Helper methods
    pub fn myMethod(self: *IMyInterface, ...) HRESULT {
        return self.vtbl.MyMethod(self, ...);
    }
};
```

### Error Handling Pattern
```zig
// Use error context for detailed error tracking
const error_context = error_handling.ErrorContext.init(
    hr, 
    "MethodName", 
    "ComponentName"
);

if (winrt_core.isFailure(hr)) {
    return error_handler.handleError(error_context);
}
```

## 🐛 Troubleshooting

### Common Issues

**Issue**: `RoInitialize failed: 0x1`
- **Solution**: This is `S_FALSE`, meaning WinRT was already initialized. This is normal.

**Issue**: Application runs but no window appears
- **Solutions**: 
  - Enable Developer Mode in Windows Settings
  - Run from Developer Command Prompt
  - Check that Windows 10+ is installed
  - Verify UWP deployment requirements

**Issue**: Library linking errors
- **Solution**: Ensure all required `.lib` files are in `Libs/` directory with correct architecture (x64/x86)

**Issue**: `E_NOINTERFACE` errors
- **Solution**: Check GUID definitions match Windows SDK headers exactly

### Debug Steps
1. Run `zig build test-winrt` to verify WinRT availability
2. Run `zig build test-modules` to test individual components  
3. Check error handler output for detailed diagnostics
4. Enable verbose logging in development builds

## 🎯 Future Extensions

This modular architecture supports easy extension:

- **XAML UI**: Add XAML interfaces in `ui/xaml.zig`
- **Additional APIs**: Add new WinRT APIs in `interfaces/` 
- **Custom Controls**: Implement in `implementation/`
- **Storage APIs**: Add file/data management modules
- **Networking**: Add HTTP/Socket WinRT wrappers
- **Graphics**: Add Direct2D/Direct3D integration

## 📝 License

This project serves as an educational example of pure WinRT development in Zig. Use and modify as needed for your projects.

## 🤝 Contributing

This is a demonstration project showing professional WinRT architecture in Zig. The modular design makes it easy to extend and adapt for real-world applications.

---

**Note**: This implementation demonstrates pure WinRT without Win32 dependencies, making it compatible with the full range of Windows devices that support WinRT, including those with Win32 API restrictions.