# Mbox - Multi-Process Key Sender

**Mbox** is an AutoHotkey v1 script that sends keyboard (and optional mouse) input to several target windows at once—by PID and/or process name—without relying on global hotkeys inside the game.

## Main features

* **Multi-process** — many targets in one run (PID list, process names, or mixed input)
* **Dynamic process tracking** — dead processes are removed and newly opened windows of the same executable are picked up automatically every second; no script restart needed
* **Several key groups** — each group has its own key sequence and repeat interval
* **Precision scheduling** — one engine with `QueryPerformanceCounter` (microsecond resolution), absolute scheduling (`nextFire += interval`) so drift never accumulates, and an active wait for the last 2 ms (±0.1–0.5 ms in practice); `timeBeginPeriod(1)` is set globally
* **Two send pipelines** (switch in script or live with **Numpad 0**):
  * **Simulation** (`UseSimulation := true`) — `ControlSend` for keys, mouse via posted messages aimed at the same per-target HWND as in the script
  * **Direct / WM** (`UseSimulation := false`) — keys via `PostMsgToFocus` / `PostTapVkFocused`; mouse via the same three posted messages (move + down + up) through `PostMsgToFocus`
* **Full combination capture** — hold any key and press another (or click a mouse button) to record one combined token: `{F+D}`, `{Esc+E}`, `{CapsLock+D}`, `{Ctrl+F}`, `{Shift+LButton}`, chains like `{F+D+G}`; all keys can act as modifiers, not just Shift/Ctrl/Alt/Win
* **Click-gated key picker** — keyboard and mouse capture is armed by clicking the key list box (it turns green); Enter/Space/Tab/Esc/Backspace are recorded as binds instead of pressing GUI buttons, and the interval field accepts digits only
* **Hold token** — `{HOLD<ms>|<keyspec>}` keeps a key or mouse button down for `ms` milliseconds; **`ms` = 0** means hold until you turn the script off, change keys, or exit (infinite hold is released on those actions); an empty interval field records `HOLD0` (instant tap) instead of the default
* **Named countdown timers** — up to 3 timers with custom names, shown live in the status GUI with remaining/total time and a progress bar; expiry triggers beeps and a restart dialog, hotkeys `Numpad /` and `Numpad 7/8/9`
* **Unicode** — sensible handling for layouts and non-ASCII where the chosen pipeline allows; key names are resolved through the active keyboard layout (`GetKeyNameText`), so `Ctrl+Ф` records correctly on a Russian layout
* **Mouse tokens** — `{LButton}` / `{RButton}` / `{MButton}` / `{XButton1}` / `{XButton2}`; clicks always go to the cursor's current position mapped into the target window; the physical cursor never moves, and no blocking `SendMessage` calls are made (normal desktop input like `Ctrl+C` is never interfered with)
* **Status GUI** — groups, keys, effective repeat interval, mode line, targets, timer progress; auto-resizes as the process count changes
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

1. **Key Selection** — click the white list box to arm capture (it turns green), then press keys or mouse buttons; hold two keys together to record a combination. Set **Interval (ms)** for the group (digits only). **Add Timer** adds a named countdown timer. Confirm when done.
2. **Processes** — enter PIDs and/or names as in the InputBox hint (`1234 notepad`, etc.).
3. **Numpad Enter** — start/stop sending. Status GUI and indicator reflect state, and the process list keeps itself up to date while the script runs.

### Hotkeys (defaults)

| Key | Action |
|-----|--------|
| **Numpad Enter** | Start / stop |
| **Numpad +** | Reconfigure keys (resets groups) |
| **Numpad .** | Show / hide status GUI |
| **Numpad \*** | Disable / enable all binds (exit still works); recorded as a bind while capture is armed |
| **Numpad 0** | Toggle **simulation vs direct** send mode (tooltip ~1.5 s) |
| **Numpad /** | Start / pause all timers |
| **Numpad 7 / 8 / 9** | Start / pause timer 1 / 2 / 3 |
| **Numpad -** | Exit script; recorded as a bind while capture is armed |

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
* **Combinations**: `{F+D}` `{Esc+E}` `{CapsLock+D}` `{Shift+A}` `{Ctrl+S}` `{F+D+G}` … — any key can be a modifier
* **Mouse**: `{LButton}` `{RButton}` `{MButton}` `{XButton1}` `{XButton2}`, with modifiers `{Shift+LButton}` `{F+RButton}` …
* **Hold**: `{HOLD500|e}` — hold `e` for 500 ms. `{HOLD0|LButton}` — hold left mouse until stop / reconfigure / exit. Inside `|`, the part after the first `|` is a **keyspec** (same style as inside `{…}` for named keys, e.g. `LButton`, `Ctrl+1`, `F+D`).

## Sending methods (summary)

### Simulation (`UseSimulation := true`)

Keys: `ControlSend` to the stored target HWND, modifiers pressed by VK code. Mouse tokens: posted `WM_MOUSEMOVE` + button down/up at the resolved client coordinates (asynchronous — never blocks the script thread). Good when you need injected input closer to “real” typing from the OS’s point of view.

### Direct (`UseSimulation := false`)

Keys: posted `WM_KEYDOWN` / `WM_KEYUP` messages (and related paths) to the focus root derived for each target—see `PostMsgToFocus` / `PostTapVkFocused` in the script. Mouse: `WM_MOUSEMOVE` + button down + button up posts. Fast and avoids activating the window for each action, but behavior depends on how the game handles message-based input.

### Timers

Created in the key selection window (**Add Timer** — name + seconds, up to 3). Live in the status overlay as `> Buff: 03:25/05:00 ######---` (`>` running, `|` paused, bar = time left). On expiry: three beeps and a restart dialog. Timers are independent of the key engine and can be changed without redoing setup.

## GitHub

https://github.com/Gariloz/Mbox

---

**Author:** Gariloz
