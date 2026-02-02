# Flux

A minimalist, always-visible stopwatch for macOS.

Flux displays as a semi-transparent text overlay that floats above all your windows — perfect for tracking work sessions, meetings, or any timed activity without getting in your way.

## Features

- **Persistent** — Remembers your time if you quit and reopen the app
- **Always visible** — Stays on top of all windows and across all desktops
- **Draggable** — Position it anywhere on your screen
- **Customizable** — Change font, size, color, opacity, and shortcuts

## Usage

### Basic Controls

| Action | What it does |
|--------|--------------|
| **Click** | Pause / Resume |
| **Right-click** | Reset to 00:00 |
| **Drag** | Move the timer |

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Space` | Pause / Resume |
| `⌘C` | Copy time (in minutes) |
| `⌘S` | Set a specific time |
| `⌘Y` | View history |
| `⌘,` | Open settings |
| `⌘Q` | Quit |

### Copy Time

Press `⌘C` to copy the elapsed time as minutes to your clipboard. The time is rounded to the nearest minute (30+ seconds rounds up).

Example: `1:23:45` → copies `84`

## Settings

Press `⌘,` to customize:

**Appearance**
- Font family and size
- Text color
- Opacity (how transparent the timer appears)

**Shortcuts**
- Rebind any keyboard shortcut
- Customize mouse click actions

**General**
- Launch at login

## Time Display

- Under 1 hour: `MM:SS` (e.g., `05:30`)
- 1 hour or more: `H:MM:SS` (e.g., `1:30:00`)

## Requirements

- macOS 15 (Sequoia) or later

## Installation

1. Download the latest release
2. Move `Flux.app` to your Applications folder
3. Open Flux

To quit, press `⌘Q`.

## Building from Source

Requires Xcode 16+.

```bash
git clone https://github.com/user/flux.git
cd flux
xcodebuild -project Flux.xcodeproj -scheme Flux build
open build/Release/Flux.app
```

Or open `Flux.xcodeproj` in Xcode and press `⌘R`.

## License

Apache 2.0
