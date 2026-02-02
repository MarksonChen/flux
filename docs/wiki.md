# Flux — Lightweight macOS Stopwatch

## Overview

Flux is a minimalist, always-visible stopwatch for macOS. It displays as a single semi-transparent text overlay that floats above all windows, providing an unobtrusive timing solution for tracking work sessions, meetings, or any timed activity.

- **Target Platform:** macOS 15+ (Sequoia)
- **Framework:** AppKit (Swift)
- **App Type:** LSUIElement (no Dock icon)

---

## Features

- **Always-on-top floating timer** — Visible across all desktops and spaces
- **Sleep-resistant timing** — Accurate through system sleep using timestamp-based calculation
- **Persistent state** — Timer continues across app restarts
- **Customizable appearance** — Font, size, color, and opacity
- **Event history** — Log of all timer events (start, pause, reset, set)
- **Configurable shortcuts** — Rebindable keyboard and mouse actions
- **Multi-monitor support** — Remembers position on specific displays
- **Glassmorphism UI** — Modern frosted glass design for dialog windows

---

## Architecture

### File Structure

```
Flux/
├── FluxApp.swift              # App delegate and window coordination
├── Controllers/
│   ├── TimerController.swift  # Timer state management (singleton)
│   └── EventLogger.swift      # Event history persistence (singleton)
├── Models/
│   ├── TimerState.swift       # Timer calculation logic
│   ├── Settings.swift         # AppSettings, ShortcutBindings, MouseAction
│   └── TimerEvent.swift       # Event log entry model
├── Utilities/
│   ├── Persistence.swift      # UserDefaults wrapper (singleton)
│   ├── ShortcutManager.swift  # Keyboard/mouse input routing (singleton)
│   ├── TimeFormatter.swift    # Time display formatting
│   └── DesignConstants.swift  # UI design tokens (spacing, colors, sizes)
├── Views/
│   ├── TimerWindow.swift      # Main floating timer window
│   ├── TimerView.swift        # Timer display (Combine-based reactive UI)
│   ├── GlassWindow.swift      # Base window with glassmorphism effect
│   ├── SetTimeWindow.swift    # Set time dialog
│   ├── SettingsWindow.swift   # Settings with tabs
│   ├── HistoryWindow.swift    # Event history table
│   └── ShortcutRecorderView.swift  # Keyboard shortcut capture widget
└── Resources/
    └── Assets.xcassets
```

### Core Design Patterns

| Pattern | Usage |
|---------|-------|
| **Singleton** | `TimerController`, `ShortcutManager`, `Persistence`, `EventLogger` |
| **Delegate** | `ShortcutManagerDelegate`, `SettingsWindowDelegate` |
| **Combine/Reactive** | `TimerController` publishes `displayTime` for `TimerView` |
| **Composition** | `TimerController` owns `TimerState` for calculations |

### Data Flow

```
User Input → ShortcutManager.handle*()
  → FluxApp (delegate methods)
  → TimerController (action)
  → TimerState (mutation)
  → EventLogger.log*()
  → Persistence.save()
  → TimerView (updates via Combine publisher)
```

---

## Timer Logic (Sleep-Resistant)

The timer uses timestamp-based calculation to remain accurate through system sleep:

### State Properties

- `accumulated: TimeInterval` — Total elapsed time stored
- `previousTimestamp: TimeInterval` — Last known timestamp (seconds since 1970)
- `isRunning: Bool` — Current running state

### Display Formula

```swift
if isRunning:
    currentElapsed = accumulated + (now - previousTimestamp)
else:
    currentElapsed = accumulated
```

### State Transitions

| Action | State Change |
|--------|--------------|
| **Start/Resume** | Set `previousTimestamp = now`, `isRunning = true` |
| **Pause** | Add elapsed to `accumulated`, set `isRunning = false` |
| **Reset** | Set `accumulated = 0`, preserve `isRunning` state |
| **Set Time** | Set `accumulated = newValue`, preserve `isRunning` state |

### Resume from Persistence

On app launch, if timer was running when closed:
1. Calculate time elapsed since close: `elapsed = now - previousTimestamp`
2. Update: `accumulated += elapsed`, `previousTimestamp = now`
3. Continue running

---

## Time Display Format

- **Under 1 hour:** `MM:SS` with leading zeros (e.g., `01:02`, `59:59`)
- **1 hour or more:** `H:MM:SS` without leading zero on hours (e.g., `1:23:45`, `99:59:59`)
- **No maximum:** Timer continues indefinitely past `99:59:59`

---

## User Interface

### Main Timer Window

| Property | Value |
|----------|-------|
| Font | Configurable (default: Arial Black) |
| Size | Configurable (default: 32pt) |
| Color | Configurable (default: #5DFFFF cyan) |
| Opacity | Configurable (default: 18%) |
| Background | Fully transparent |
| Window Level | Floating above all windows |
| Dock Icon | None (LSUIElement) |

### Window Behavior

- **Position persistence:** Remembers location across launches
- **Multi-display support:** Remembers which monitor and clamps to screen bounds
- **Click-through:** Window receives direct interactions only
- **Collection behavior:** Joins all spaces, stationary, full-screen auxiliary

### Glassmorphism Dialog Windows

All dialog windows (Set Time, History, Settings) use a consistent glass design:

- **NSVisualEffectView** with `.fullScreenUI` material for blur
- **Gradient overlay:** White gradient from top (medium opacity → subtle → clear)
- **Border highlight:** White 1pt border at bottom with 30% opacity
- **Rounded corners:** 16pt radius
- **Movable by background drag**

---

## Interactions

### Default Mouse Actions

| Action | Behavior |
|--------|----------|
| Left-click | Toggle pause/resume |
| Right-click | Reset to 00:00 (preserves running/paused state) |
| Left double-click | None (configurable) |
| Right double-click | None (configurable) |
| Drag | Reposition window |

### Default Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Space` | Toggle pause/resume |
| `⌘C` | Copy current time in rounded minutes |
| `⌘S` | Open Set Time window |
| `⌘Y` | Open History window |
| `⌘,` | Open Settings window |
| `⌘Q` | Quit application |

### Copy Behavior (⌘C)

Rounds to nearest minute using standard rounding (≥30 seconds rounds up).
Example: `1:23:45` → `84` copied to clipboard.

---

## Windows

### Set Time Window (⌘S)

Allows setting the timer to a specific value.

**Components:**
- Three input fields: Hours (0–999), Minutes (0–59), Seconds (0–59)
- "Set Time" button — applies the new time
- "Cancel" button — dismisses without changes

**Behavior:**
- Timer continues running while dialog is open
- After setting: timer preserves its previous running/paused state
- Creates a "Set" event in history (e.g., `45:00 → 25:00`)
- ESC key closes window

### History Window (⌘Y)

Displays a log of timer events.

**Table Columns:**

| Column | Format | Example |
|--------|--------|---------|
| Time | `MM/dd HH:mm:ss` | `12/31 23:59:59` |
| Change | Value + symbol | `03:22 ⏸` |
| Event | Event type (color-coded) | `Paused` |

**Change Column Formats:**
- Started: `03:22 ▶` (green)
- Paused: `03:22 ⏸` (orange)
- Restarted: `45:00 → 00:00` (red)
- Set: `45:00 → 25:00` (blue)

**Behavior:**
- Newest entries at top
- Maximum 100 entries (oldest automatically removed)
- Read-only display
- ESC key closes window

### Settings Window (⌘,)

Tabbed interface with three sections: **Appearance**, **Shortcuts**, **General**

#### Appearance Tab

| Setting | Control | Range |
|---------|---------|-------|
| Font | Popup button | System fonts + all available |
| Size | Slider | 12–120pt |
| Color | Color well | Full color selection |
| Opacity | Slider | 0–100% |
| Reset button | — | Restore appearance defaults |

#### Shortcuts Tab

**Keyboard Shortcuts:**
- Toggle pause/resume (no modifier required)
- Copy time (⌘ required)
- Set time (⌘ required)
- History (⌘ required)
- Settings (⌘ required)
- Quit (⌘ required)

**Mouse Actions:**
- Left-click action
- Right-click action
- Left double-click action
- Right double-click action

Options for each: Toggle Pause/Resume, Reset, None

**Validation:**
- Duplicate shortcuts are detected and prevented
- Alert shown when attempting to assign an already-used shortcut

#### General Tab

- **Launch at login** toggle — Uses SMAppService (macOS 13+)

**Behavior:**
- Changes apply immediately (no Save button)
- Per-section "Reset to Defaults" button
- ESC key closes window
- ⌘W closes window

---

## Persistence

All data stored in UserDefaults via `Persistence.shared`:

### Stored Keys

| Key | Type | Description |
|-----|------|-------------|
| `timerState` | JSON | Timer accumulated time and running state |
| `appSettings` | JSON | Appearance settings |
| `shortcutBindings` | JSON | Keyboard and mouse bindings |
| `timerEvents` | JSON | Event history array (max 100) |
| `windowX`, `windowY` | Double | Window position coordinates |
| `windowDisplayID` | Int | Display ID for multi-monitor |

### Default Values

| Setting | Default |
|---------|---------|
| Font | Arial Black |
| Font Size | 32pt |
| Color | #5DFFFF (cyan) |
| Opacity | 18% |
| Launch at Login | Off |
| Max History | 100 entries |

---

## Event Types

| Event | Trigger | Change Format |
|-------|---------|---------------|
| Started | Resume from pause or initial start | `MM:SS ▶` |
| Paused | Pause running timer | `MM:SS ⏸` |
| Restarted | Right-click reset | `MM:SS → 00:00` |
| Set | Confirm in Set Time window | `MM:SS → MM:SS` |

---

## Components Reference

### FluxApp.swift

Main application delegate managing:
- Window lifecycle (timer window, lazy dialog controllers)
- `ShortcutManagerDelegate` implementation for routing actions
- `SettingsWindowDelegate` implementation for appearance refresh
- Dialog positioning (10px above timer window)

### TimerController.swift

Singleton (`TimerController.shared`) managing:
- `@Published state: TimerState` — Timer state
- `@Published displayTime: String` — Formatted time (updated every 0.1s)
- Timer actions: `togglePauseResume()`, `reset()`, `setTime(_:)`, `copyTimeToClipboard()`
- Event logging delegation to `EventLogger`

### TimerState.swift

Codable struct with:
- Sleep-resistant timestamp-based calculation
- `start()`, `pause()`, `toggle()`, `reset()`, `setTime(_:)` methods
- `resumeFromPersistence()` for app launch recovery

### EventLogger.swift

Singleton (`EventLogger.shared`) managing:
- Event creation: `logStarted(at:)`, `logPaused(at:)`, `logRestarted(from:)`, `logSet(from:to:)`
- Maximum 100 entries with automatic cleanup
- Persistence via `Persistence.shared.timerEvents`

### ShortcutManager.swift

Singleton (`ShortcutManager.shared`) managing:
- `ShortcutManagerDelegate` protocol for action callbacks
- `handleKeyDown(_:)` — Keyboard event routing
- `handleLeftClick()`, `handleRightClick()`, etc. — Mouse event routing

### TimerWindow.swift

Main floating NSWindow with:
- Borderless, transparent, floating configuration
- Drag-to-reposition with position saving
- Click event handling (single, double, left, right)
- Keyboard event routing to ShortcutManager
- Multi-monitor position restoration

### TimerView.swift

NSView with Combine-based reactive display:
- Subscribes to `TimerController.shared.$displayTime`
- Dynamic window sizing based on text content
- Settings-driven appearance (font, color, opacity)

### GlassWindow.swift

Base NSWindow class providing:
- Glassmorphism visual effect (blur, gradient, border)
- Standard window configuration for dialogs
- ⌘W close handling

### DesignConstants.swift

Design system tokens:
- Corner radii: small (8), medium (12), large (16)
- Spacing: 8pt grid (xs=4, sm=8, md=16, lg=24, xl=32)
- Opacity levels: subtle (0.05), light (0.1), medium (0.15), border (0.3)
- Component dimensions (input fields, buttons, sliders, tables)
- Font sizes: xs (11), sm (12), base (13), lg (24)
- Window sizes for timer, dialogs

---

## Build & Run

### Using Xcode

Open `Flux.xcodeproj` in Xcode and press `⌘R` to build and run.

### Using Command Line

```bash
# Build
xcodebuild -project Flux.xcodeproj -scheme Flux build

# Build and run
xcodebuild -project Flux.xcodeproj -scheme Flux build && open build/Release/Flux.app

# Clean build
xcodebuild -project Flux.xcodeproj -scheme Flux clean build
```
