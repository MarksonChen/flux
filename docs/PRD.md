# PRD: Flux — Lightweight macOS Stopwatch

## Overview

Flux is a minimalist, always-visible stopwatch for macOS. It displays as a single semi-transparent text overlay that floats above all windows, providing an unobtrusive timing solution for tracking work sessions, meetings, or any timed activity.

**Target Platform:** macOS 15 (Sequoia)
**Framework:** AppKit (Swift)
**App Type:** LSUIElement (no Dock icon)

---

## Core Functionality

### Time Calculation (Sleep-Resistant)

The stopwatch must use timestamp-based calculation to remain accurate through system sleep:

```
On start/resume:
  prev = current_timestamp

On pause:
  acc += current_timestamp - prev
  prev = current_timestamp

Display (while running):
  show acc + (current_timestamp - prev)

Display (while paused):
  show acc
```

**Key requirement:** The timer state persists across app restarts. When reopened, the app resumes as if it was never closed (recalculates elapsed time from stored timestamps).

### Time Display Format

- **Under 1 hour:** `MM:SS` with leading zeros (e.g., `01:02`, `59:59`)
- **1 hour or more:** `H:MM:SS` without leading zero on hours (e.g., `1:23:45`, `99:59:59`, `100:00:00`)
- **No maximum:** Timer continues indefinitely past 99:59:59

---

## User Interface

### Main Timer Window

| Property | Value |
|----------|-------|
| Font | SF Pro (system) |
| Size | 36pt (configurable) |
| Color | White (configurable) |
| Opacity | 50% (configurable) |
| Shadow | Optional, configurable |
| Background | Fully transparent, click-through |
| Window Level | Floating above all windows |
| Dock Icon | None (LSUIElement) |

**State Indication:** No visual difference between running and paused states.

### Window Behavior

- **Position persistence:** Remembers location across launches
- **Multi-display support:** Remembers which monitor the timer was placed on
- **Click-through:** Window does not intercept clicks except for direct timer interactions

---

## Interactions

### Mouse Actions

| Action | Behavior |
|--------|----------|
| Left-click | Toggle pause/resume |
| Right-click | Reset to 00:00 (immediate, preserves running/paused state) |
| Drag | Reposition window (works while running or paused) |

### Keyboard Shortcuts (Default)

| Shortcut | Action |
|----------|--------|
| `Space` | Toggle pause/resume |
| `⌘C` | Copy current time in minutes (standard rounding) |
| `⌘S` | Open Set Time window |
| `⌘Y` | Open History window |
| `⌘,` | Open Settings window |
| `⌘Q` | Quit application |

**Copy behavior (⌘C):** Rounds to nearest minute using standard rounding (≥30 seconds rounds up). Example: `1:23:45` → `84` copied to clipboard.

---

## Windows

### Set Time Window (⌘S)

Allows setting the timer to a specific value.

**Components:**
- Three spinner controls: Hours (0–999+), Minutes (0–59), Seconds (0–59)
- "Set Time" button — applies the new time
- "Cancel" button — dismisses without changes
- ESC key closes window

**Behavior:**
- Timer continues running while dialog is open
- After setting: timer preserves its previous running/paused state
- Creates a "set" event in history (e.g., "45:00 → 25:00")

### History Window (⌘Y)

Displays a log of timer events.

**Table Columns:**

| Column | Format | Example |
|--------|--------|---------|
| Time | `MM/DD HH:MM:SS` | `12/31 23:59:59` |
| Change | Value + symbol | `03:22 ⏸` |
| Event | Event type | `Paused` |

**Change Column Formats:**
- Paused: `03:22 ⏸`
- Started: `01:00 ▶`
- Restarted (reset): `45:00 → 00:00`
- Set (custom time): `45:00 → 25:00`

**Event Types:**
- `Paused` — timer stopped
- `Started` — timer began running
- `Restarted` — reset to 00:00
- `Set` — time manually adjusted

**Behavior:**
- Newest entries at top
- Maximum 20 entries (configurable in Settings)
- Read-only (no manual deletion)
- Old entries automatically removed when exceeding maximum
- ESC key closes window

### Settings Window (⌘,)

Tabbed interface with sections: **Appearance**, **Shortcuts**, **History**, **General**

#### Appearance Tab
- Font family picker (system fonts)
- Font size slider/stepper
- Text color picker
- Opacity slider (0–100%)
- Drop shadow toggle

#### Shortcuts Tab
- Rebindable keyboard shortcuts for all actions
- Rebindable mouse actions (left-click, right-click behavior)

#### History Tab
- Maximum entries count (default: 20)

#### General Tab
- Launch at login toggle (adds/removes from login items)

**Behavior:**
- Changes apply immediately (no Save button)
- Per-section "Reset to Defaults" button
- ESC key closes window

---

## Persistence (UserDefaults)

### Settings
- Font family, size, color, opacity
- Shadow enabled/disabled
- All keyboard and mouse shortcut bindings
- Maximum history entries
- Launch at login preference

### State
- Window position (x, y coordinates)
- Window display ID (for multi-monitor)
- Timer accumulated time (`acc`)
- Previous timestamp (`prev`)
- Running/paused state
- Event history (array of entries)

### Resume Logic

On app launch:
1. Load saved state from UserDefaults
2. If timer was running when closed:
   - Calculate time elapsed since close: `elapsed = current_timestamp - prev`
   - Update: `acc += elapsed`, `prev = current_timestamp`
   - Continue running
3. If timer was paused: display saved `acc`, remain paused

---

## Events Logged

| Event | Trigger | Change Format |
|-------|---------|---------------|
| Started | Resume from pause or initial start | `MM:SS ▶` |
| Paused | Pause running timer | `MM:SS ⏸` |
| Restarted | Right-click reset | `MM:SS → 00:00` |
| Set | Confirm in Set Time window | `MM:SS → MM:SS` |

---

## Technical Requirements

### Window Configuration
- `NSWindow.Level.floating` for always-on-top
- `NSWindow.StyleMask.borderless` for no chrome
- `backgroundColor = .clear` with `isOpaque = false`
- `ignoresMouseEvents = true` for click-through (toggled for interactions)
- `collectionBehavior = [.canJoinAllSpaces, .stationary]` for multi-desktop

### Timer Update
- Use `Timer` or `CADisplayLink` for display updates
- Recommended update interval: 100ms (0.1 seconds) for smooth display
- Timestamp source: `Date().timeIntervalSince1970` or `CFAbsoluteTimeGetCurrent()`

### Accessibility
- Expose timer value via accessibility APIs
- VoiceOver support for reading current time

---

## Default Values

| Setting | Default |
|---------|---------|
| Font | SF Pro |
| Font Size | 36pt |
| Color | White |
| Opacity | 50% |
| Shadow | Off |
| Max History | 20 entries |
| Launch at Login | Off |

---

## Launch Behavior

1. App starts immediately counting from 00:00 (or resumes from persisted state)
2. Window appears at last saved position (or center of main display if first launch)
3. No Dock icon, no menu bar icon
4. Quit via ⌘Q only

---

## File Structure (Recommended)

```
Flux/
├── FluxApp.swift              # App entry point
├── Models/
│   ├── TimerState.swift       # Timer state model
│   ├── TimerEvent.swift       # Event log model
│   └── Settings.swift         # User preferences model
├── Views/
│   ├── TimerWindow.swift      # Main floating window
│   ├── TimerView.swift        # Timer display view
│   ├── SetTimeWindow.swift    # Set time dialog
│   ├── HistoryWindow.swift    # Event history table
│   └── SettingsWindow.swift   # Preferences window
├── Controllers/
│   ├── TimerController.swift  # Timer logic
│   └── EventLogger.swift      # Event persistence
├── Utilities/
│   ├── Persistence.swift      # UserDefaults wrapper
│   ├── ShortcutManager.swift  # Keyboard/mouse handling
│   └── TimeFormatter.swift    # Time display formatting
└── Resources/
    └── Assets.xcassets
```

---

## Verification & Testing

### Manual Testing Checklist

- [ ] Timer continues accurately after Mac wakes from sleep
- [ ] Timer resumes correctly after app restart
- [ ] Window position persists across launches
- [ ] Multi-monitor: window appears on correct display
- [ ] Left-click toggles pause/resume
- [ ] Right-click resets and preserves running/paused state
- [ ] Drag repositions window while running
- [ ] ⌘C copies rounded minutes to clipboard
- [ ] ⌘S opens Set Time, timer keeps running in background
- [ ] Set Time preserves running/paused state after confirmation
- [ ] ⌘Y shows history with correct event formats
- [ ] History limited to max entries, newest first
- [ ] ⌘, opens Settings, changes apply immediately
- [ ] Per-section reset to defaults works
- [ ] Space bar toggles pause/resume
- [ ] ESC closes Set Time, History, and Settings windows
- [ ] ⌘Q quits the app
- [ ] Launch at login toggle works
- [ ] All shortcuts are rebindable in Settings
- [ ] Timer displays correctly at 59:59, 1:00:00, 99:59:59, 100:00:00
