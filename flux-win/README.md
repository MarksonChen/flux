# Flux for Windows

A minimalist, always-visible stopwatch overlay for your desktop. Flux renders as a single semi-transparent text label that floats above all other windows — no taskbar icon, no system tray, no Alt+Tab entry. Just a timer, always there when you need it.

Flux for Windows is a faithful port of the original [Flux for macOS](https://github.com/MarksonChen/flux).

## Features

- **Always-on-top overlay** — a floating `HH:MM:SS` label rendered directly on the desktop
- **Sleep-resistant timing** — uses wall-clock timestamps, not ticks; survives sleep/hibernate
- **Persistent state** — timer, settings, position, and history survive app restarts
- **Configurable appearance** — font family, size (pt), color, and opacity
- **Event history** — timestamped log of start, pause, reset, copy, and set events
- **Keyboard shortcuts** — fully rebindable local shortcuts for all actions
- **Global hotkeys** — control the timer from any app without focusing Flux
- **Mouse bindings** — configurable left/right click and double-click actions
- **Multi-monitor aware** — restores position to the correct monitor
- **Auto-hide** — optionally hides when a fullscreen app occupies the same monitor
- **Launch at login** — optional Windows startup registration
- **Glass-styled dialogs** — settings, history, and set-time windows with acrylic/glass backdrop

## Requirements

- **To run a release build:** Windows 10 or 11, 64-bit. No other dependencies.
- **To build from source:** [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0). No external NuGet packages required.

## Build & Run

All commands are run from the `flux-win/` directory.

```bash
cd flux-win

# Build
dotnet build

# Run (debug)
dotnet run --project Flux
```

## Release

Publish a self-contained single-file executable. The output is a single `Flux.exe` (~166 MB) that runs on any 64-bit Windows 10/11 machine with **no .NET installation required**.

```bash
dotnet publish Flux -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true
```

Output: `Flux/bin/Release/net10.0-windows/win-x64/publish/Flux.exe`

To distribute, just share `Flux.exe` — the `.pdb` file (debug symbols) is not needed.

## Usage

Once launched, the timer overlay (`00:00`) appears on your desktop. There is no other UI — the overlay **is** the app.

### Keyboard Shortcuts (when overlay is focused)

| Shortcut | Action |
|---|---|
| `Space` | Start / pause the timer |
| `Ctrl+C` | Copy elapsed time (rounded to nearest minute) |
| `Ctrl+S` | Open the Set Time dialog |
| `Ctrl+Y` | Open the Event History window |
| `Ctrl+,` | Open Settings |
| `Ctrl+Q` | Quit Flux |

All local shortcuts can be rebound in Settings.

### Global Hotkeys (work from any app)

| Shortcut | Action |
|---|---|
| `Ctrl+Alt+T` | Toggle start / pause |
| `Ctrl+Alt+Shift+T` | Copy time + reset |

Global hotkeys can be rebound or disabled in Settings.

### Mouse

| Action | Default binding |
|---|---|
| Left-click + drag | Move the overlay |
| Right-click | Reset the timer |

Mouse bindings (left click, right click, double-clicks) are configurable in Settings.

### Set Time

Press `Ctrl+S` to open the Set Time dialog. Enter minutes directly (e.g. `90`) and it automatically converts to `1:30:00`.

## Persistence

All state is saved to:

```
%LOCALAPPDATA%\Flux\state.json
```

This includes: timer state, settings, shortcut bindings, mouse bindings, global hotkey config, event history, and window position.

## Project Structure

```
flux-win/
├── Flux/
│   ├── App.xaml(.cs)              # Application entry point, startup logic
│   ├── Models/                    # Data models
│   │   ├── AppSettings.cs         # Font, color, opacity, launch-at-login
│   │   ├── PersistedState.cs      # Root state object (serialized to JSON)
│   │   ├── TimerState.cs          # Elapsed time, running flag, wall-clock anchor
│   │   ├── TimerEvent.cs          # History event record
│   │   ├── LocalShortcutBindings.cs   # Rebindable keyboard shortcuts
│   │   ├── GlobalHotkeyBindings.cs    # System-wide hotkey config
│   │   ├── MouseBindings.cs       # Click/double-click action mapping
│   │   └── WindowPlacementState.cs    # Monitor-aware position restore
│   ├── Views/                     # WPF windows and controls
│   │   ├── TimerWindow.xaml(.cs)      # Main overlay window
│   │   ├── SettingsWindow.xaml(.cs)   # Tabbed settings dialog
│   │   ├── HistoryWindow.xaml(.cs)    # Event history viewer
│   │   ├── SetTimeWindow.xaml(.cs)    # Set/adjust timer dialog
│   │   ├── GlassWindowBase.cs         # Acrylic/glass backdrop base class
│   │   └── Controls/                  # Reusable controls (shortcut recorder)
│   ├── Services/                  # Core services
│   │   ├── TimerController.cs     # Timer logic (start, pause, reset, elapsed)
│   │   ├── PersistenceService.cs  # JSON state load/save with debounce
│   │   ├── EventLogger.cs         # Event history recording
│   │   ├── GlobalHotkeyService.cs # Win32 RegisterHotKey wrapper
│   │   ├── ShortcutService.cs     # Local keyboard shortcut dispatcher
│   │   ├── FullscreenMonitor.cs   # Detects fullscreen apps for auto-hide
│   │   ├── StartupRegistrationService.cs  # Launch-at-login registry management
│   │   └── VirtualDesktopService.cs       # Virtual desktop pinning
│   ├── Interop/                   # Win32/DWM P/Invoke layer
│   │   ├── NativeMethods.cs       # LibraryImport declarations
│   │   ├── NativeConstants.cs     # Win32 constants
│   │   └── NativeStructs.cs       # Win32 struct definitions
│   ├── Utilities/                 # Helpers
│   │   ├── TimeFormatter.cs       # HH:MM:SS formatting
│   │   ├── FontUnitConverter.cs   # Points ↔ WPF units
│   │   ├── DesignTokens.cs        # UI constants
│   │   └── WindowPositioning.cs   # Screen bounds / DPI logic
│   ├── Infrastructure/            # MVVM plumbing
│   │   ├── ObservableObject.cs
│   │   ├── RelayCommand.cs
│   │   ├── SingleInstanceGuard.cs # Named mutex for single-instance enforcement
│   │   └── Debouncer.cs
│   └── Resources/
│       └── ModernTheme.xaml       # Styles, brushes, and control templates
├── docs/
│   └── PRD.md                     # Product requirements document
└── flux.sln                       # Visual Studio solution
```

## License

See the repository root for license information.
