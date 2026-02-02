# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flux is a minimalist macOS stopwatch application that displays as a semi-transparent floating text overlay. It runs as an LSUIElement (no Dock icon) and is built with Swift/AppKit targeting macOS 15+.

## Build Commands

```bash
# Build the project
xcodebuild -project Flux.xcodeproj -scheme Flux build

# Build and run
xcodebuild -project Flux.xcodeproj -scheme Flux build && open build/Release/Flux.app

# Clean build
xcodebuild -project Flux.xcodeproj -scheme Flux clean build
```

Or open `Flux.xcodeproj` in Xcode and use Cmd+R to build and run.

## Architecture

### Core Design Patterns

- **Singletons**: `TimerController`, `ShortcutManager`, `Persistence`, `EventLogger` are all singletons accessed via `.shared`
- **Delegate Pattern**: `ShortcutManagerDelegate` routes keyboard/mouse actions, `SettingsWindowDelegate` handles setting updates
- **Combine/ObservableObject**: `TimerController` publishes `displayTime` for reactive UI updates in `TimerView`

### Timer Logic (Sleep-Resistant)

The timer uses timestamp-based calculation to survive system sleep:
- `accumulated`: total elapsed time stored as TimeInterval
- `previousTimestamp`: last known timestamp when running
- Display formula (running): `accumulated + (now - previousTimestamp)`
- On pause: adds elapsed time to `accumulated`
- On resume: captures new `previousTimestamp`

### Key Components

- **FluxApp.swift**: App delegate, manages all window controllers, implements `ShortcutManagerDelegate`
- **TimerController**: Singleton managing timer state, updates display every 0.1s via Timer
- **TimerWindow**: Main floating NSWindow with borderless, transparent, click-through configuration
- **GlassWindow**: Base window class with glassmorphism effect (blur, gradient, border) for dialogs
- **Persistence**: UserDefaults wrapper handling JSON encoding/decoding for complex types
- **DesignConstants**: UI design tokens for consistent spacing, sizing, and styling

### Window Configuration

The main timer window uses these critical AppKit settings:
- `NSWindow.Level.floating` for always-on-top
- `NSWindow.StyleMask.borderless` for no chrome
- `backgroundColor = .clear`, `isOpaque = false` for transparency
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`

### Persistence Keys

All state stored in UserDefaults via `Persistence.shared`:
- `timerState`: Timer accumulated time and running state
- `appSettings`: Appearance settings (font, fontSize, textColorHex, opacity, launchAtLogin)
- `shortcutBindings`: Keyboard and mouse action bindings
- `timerEvents`: History log (max 100 entries)
- `windowX`, `windowY`, `windowDisplayID`: Multi-monitor aware positioning

## Default Shortcuts

| Shortcut | Action |
|----------|--------|
| Space | Toggle pause/resume |
| Cmd+C | Copy time as rounded minutes |
| Cmd+S | Open Set Time window |
| Cmd+Y | Open History window |
| Cmd+, | Open Settings window |
| Cmd+Q | Quit |
| Left-click | Toggle pause/resume |
| Right-click | Reset to 00:00 |

## Default Appearance

| Setting | Default |
|---------|---------|
| Font | Arial Black |
| Size | 32pt |
| Color | #5DFFFF (cyan) |
| Opacity | 18% |

## Reference

See [docs/wiki.md](docs/wiki.md) for comprehensive documentation.
