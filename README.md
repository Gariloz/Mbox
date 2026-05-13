# Mbox - Multi-Process Key Sender

**Mbox** is an AutoHotkey v1 script that sends keyboard (and optional mouse) input to several target windows at once—by PID and/or process name—without relying on global hotkeys inside the game.

## Main features

* **Multi-process** — many targets in one run (PID list, process names, or mixed input)
* **Several key groups** — each group has its own key sequence and repeat interval
* **Two send pipelines** (switch in script or live with **Numpad 0**):
  * **Simulation** (`UseSimulation := true`) — `ControlSend` for keys, `ControlClick` for mouse tokens, aimed at the same per-target HWND as in the script
  * **Direct / WM** (`UseSimulation := false`) — keys via `PostMsgToFocus` / `PostTapVkFocused`; mouse via the same three posted messages (move + down + up) through `PostMsgToFocus`
* **Hold token** — `{HOLD<ms>|<keyspec>}` keeps a key or mouse button down for `ms` milliseconds; **`ms` = 0** means hold until you turn the script off, change keys, or exit (infinite hold is released on those actions)
* **Key picker** — keyboard and **left/right mouse** in the “Key Selection” window: short press adds a normal token; hold **≥ 1 s** adds `{HOLD…}` using the same **Interval (ms)** field as the group delay (see script header comments for exact behavior)
* **Unicode** — sensible handling for layouts and non-ASCII where the chosen pipeline allows
* **Modifiers** — `{Shift+A}`, `{Ctrl+C}`, `{Alt+Tab}`, `{Win+R}`, etc.
* **Mouse tokens** — `{LButton}` / `{RButton}` (position: under cursor if it is over the target, otherwise client center—see code)
* **Status GUI** — groups, keys, effective repeat interval, mode line, targets
* **Indicator dot** — optional always-on-top dot (green/red, optional blink, yellow border when binds are locked)
* **Bind lock** — **Numpad \*** disables all binds except exit; status + dot show locked state
* **No focus steal** — designed around posting / control-send to chosen roots, not activating the game for every key

## Repository layout

| Path | Role |
|------|------|
| `Mbox.ahk` | **Main script** — run this from the repo root |
| `test/Mbox.ahk` | Same script kept under `test/` for experiments or diffs (keep in sync with root if you use both) |
| `test/MinimizedGame_KeyDelivery_Test.ahk` | Separate small AHK test for minimized-window delivery (not required for normal use) |
| `old (work)/Mbox.ahk` | Older reference copy |

## Installation

1. Install [AutoHotkey](https://www.autohotkey.com/) **v1.1** (Classic)
2. Clone or copy this folder
3. Run **`Mbox.ahk`** from the `Mbox` directory (double-click or run with AutoHotkey)
4. Complete key selection, then enter PID / process names as prompted

## Usage (quick)

1. **Key Selection** — click keys or use the keyboard; mouse **L/R** works when the “Key Selection” window is active. Set **Interval (ms)** for the group (also used when a hold is captured). Confirm when done.
2. **Processes** — enter PIDs and/or names as in the InputBox hint (`1234 notepad`, etc.).
3. **Numpad Enter** — start/stop sending. Status GUI and indicator reflect state.

### Hotkeys (defaults)

| Key | Action |
|-----|--------|
| **Numpad Enter** | Start / stop |
| **Numpad +** | Reconfigure keys (resets groups) |
| **Numpad .** | Show / hide status GUI |
| **Numpad \*** | Disable / enable all binds (exit still works) |
| **Numpad 0** | Toggle **simulation vs direct** send mode (tooltip ~1.5 s) |
| **Numpad -** | Exit script |

Change keys in `Mbox.ahk` under `; === Горячие клавиши ===` if needed.

### Configuration (top of `Mbox.ahk`)

Important lines (see file for full list including indicator options):

```autohotkey
DefaultInterval := 500   ; Default group interval if the field is left empty (ms)
KeyDelay := 0            ; Extra delay between keys inside one group pass (ms)
; Two lines below document simulation vs direct send in detail — read them before changing UseSimulation.
UseSimulation := false   ; false = WM/direct pipeline, true = ControlSend/ControlClick
ShowStatusGUI := true
```

The two comment lines immediately above/below `UseSimulation` in the script describe **exactly** which APIs are used in each mode.

### Key / token format

* **Single keys**: `a` `1` … or `{a}` when needed
* **Special keys**: `{Space}` `{Enter}` `{F1}` …
* **Modifiers**: `{Shift+A}` `{Ctrl+S}` …
* **Mouse**: `{LButton}` `{RButton}`
* **Hold**: `{HOLD500|e}` — hold `e` for 500 ms. `{HOLD0|LButton}` — hold left mouse until stop / reconfigure / exit. Inside `|`, the part after the first `|` is a **keyspec** (same style as inside `{…}` for named keys, e.g. `LButton`, `Ctrl+1`).

## Sending methods (summary)

### Simulation (`UseSimulation := true`)

Keys: `ControlSend` to the stored target HWND. Mouse tokens: `ControlClick` with resolved client coordinates (`NA`, down/up for holds). Good when you need injected input closer to “real” typing from the OS’s point of view.

### Direct (`UseSimulation := false`)

Keys: posted `WM_KEYDOWN` / `WM_UP` style messages (and related paths) to the focus root derived for each target—see `PostMsgToFocus` / `PostTapVkFocused` in the script. Mouse: `WM_MOUSEMOVE` + button down + button up posts. Fast and avoids activating the window for each action, but behavior depends on how the game handles message-based input.

## Changelog vs older README / `old (work)` build

* **Accurate direct mode** — no longer described as “only WM_CHAR”; current build uses the posted key/mouse pipeline above.
* **`{HOLD…}`** — timed and infinite (`0`) holds, including mouse, with release on toggle off / reconfigure / exit.
* **Key picker** — hold detection (~1 s) for keyboard and L/R mouse; interval field also drives hold duration and is saved as the group repeat interval (including **`0`** ms when you type `0`).
* **Numpad 0** — runtime toggle between simulation and direct mode.
* **GUI responsiveness** — first send pass after start is deferred slightly so the status window can repaint before long `Sleep` chains run.

## GitHub

https://github.com/Gariloz/Mbox

---

**Author:** Gariloz
