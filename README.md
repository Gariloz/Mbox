# Mbox - Multi-Process Key Sender

**Mbox** is an AutoHotkey script that allows you to send keyboard input to multiple processes simultaneously. Perfect for automating repetitive tasks across multiple windows or applications.

## Main Features

* **Multi-process support** - Send keys to multiple processes at once (by PID or process name)
* **Multiple key groups** - Create and manage multiple groups of key sequences with different intervals
* **Two sending methods**:
  - **Simulation mode** (`ControlSend`) - Simulates keyboard input, safer for anti-cheat systems
  - **Direct send mode** (`PostMessage`) - Direct message sending, fastest method, works without window activation
* **Unicode support** - Properly handles Russian characters and other Unicode symbols
* **Modifier key support** - Full support for Shift, Ctrl, Alt, Win key combinations
* **Real-time status GUI** - Visual status display showing active groups, intervals, and target processes
* **Toggle GUI visibility** - Show/hide status window with hotkey (NumpadDot)
* **Smart key parsing** - Handles keys with spaces and curly braces correctly (e.g., `{Space}`, `{Shift+A}`)
* **No window activation required** - Works in background without stealing focus

## Installation

1. Install [AutoHotkey](https://www.autohotkey.com/) (v1.1 or later)
2. Download `Mbox.ahk` file
3. Double-click `Mbox.ahk` to run
4. Configure your key groups and target processes

## Usage

### Initial Setup

1. **Select Keys**: When script starts, click the buttons you want to send (or type them)
2. **Set Interval**: Enter interval in milliseconds (default: 500ms)
3. **Add More Groups** (optional): Click "Add Another Group" to create additional key sequences
4. **Confirm Selection**: Click "Confirm Selection"
5. **Enter Process Info**: 
   - Enter PID(s): `1234 5678` or `1234.5678` or `1234,5678`
   - Enter process name(s): `notepad explorer` or `notepad.explorer`
   - Mix both: `1234 notepad`

### Hotkeys

* **Numpad Enter** - Start/Stop script execution
* **Numpad +** - Reset and reconfigure keys
* **Numpad Dot** - Toggle status GUI visibility
* **Numpad -** - Exit script

### Configuration

Edit settings at the top of `Mbox.ahk`:

```autohotkey
DefaultInterval := 500   ; Default interval for new groups (ms)
KeyDelay := 0            ; Delay between keys in sequence (ms)
UseSimulation := false   ; true = Send (simulation), false = PostMessage (direct send)
ShowStatusGUI := true    ; Show status window (true/false)
StatusPosX := 0          ; X position of status window
StatusPosY := 0          ; Y position of status window
```

### Key Format

* **Single keys**: `a`, `b`, `1`, `2`
* **Special keys**: `{Space}`, `{Enter}`, `{Tab}`, `{Esc}`, `{F1}`-`{F12}`
* **Modifiers**: `{Shift+A}`, `{Ctrl+C}`, `{Alt+F4}`, `{Win+R}`
* **Combinations**: `a {Space} b {Enter}` - sends "a", space, "b", enter
* **Russian characters**: Works correctly in both modes (PostMessage recommended for old games)

## Sending Methods

### Simulation Mode (`UseSimulation := true`)

* Uses `ControlSend` - simulates keyboard input
* Safer for anti-cheat systems
* Works without activating target windows for most keys

### Direct Send Mode (`UseSimulation := false`)

* Uses `PostMessage` with `WM_CHAR` / `WM_KEYDOWN` / `WM_KEYUP`
* Fastest method - instant key sending
* Works without window activation
* Proper Unicode support for Russian characters
* Recommended for old games (e.g., World of Warcraft)

## Changes in Version

* **Two sending methods** - Simulation and direct send modes
* **Unicode support** - Proper Russian character handling via `WM_CHAR`
* **Smart key parsing** - Custom `ParseKeys` function handles spaces and curly braces
* **Multi-process support** - Send to multiple processes simultaneously
* **Multiple groups** - Create unlimited key groups with different intervals
* **Real-time status GUI** - Visual feedback with dynamic padding
* **Toggle GUI visibility** - Show/hide status window with hotkey (NoActivate)
* **Process validation** - Verifies processes before starting
* **Interval calculation** - Shows real interval including key delays
* **Modifier key support** - Full Shift/Ctrl/Alt/Win combinations
* **Space key fix** - Proper handling of space character in both modes
* **No window activation** - Works in background (PostMessage mode)

## GitHub

https://github.com/Gariloz/Mbox

---

**Author:** Gariloz