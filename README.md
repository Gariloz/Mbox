# Faceit Auto Start

**Faceit Auto Start** is a userscript for Tampermonkey/Greasemonkey that automatically starts a new match after the current one finishes on FACEIT platform.

## Supported Games

* **Counter-Strike** (CS:GO, CS2)
* **Dota 2**

The script works with all games supported by FACEIT platform by detecting match status from page content.

## Main Features

* Automatic match completion detection - Scans entire page for match status keywords
* Multi-game support - Works with CS:GO, CS2, Dota 2 and other FACEIT games
* Smart status recognition - Multiple language support (English/Russian)
* AFK match cancellation detection - Automatically starts new match when match is cancelled due to AFK players (configurable)
* Full page scanning - Checks all visible elements on the page, not just time element
* State persistence - Remembers enabled/disabled state across browser sessions and page reloads
* Same-tab navigation - Redirects in current tab, no new windows or tabs opened
* Configurable redirect delay - Set custom delay before starting new match
* Toggle button - Easy enable/disable functionality with visual status indicator
* Works on all FACEIT pages - Compatible with all *.faceit.com pages
* Real-time monitoring - Minimal resource usage using requestAnimationFrame
* Comprehensive error handling - Better recovery from various error states
* Modal dialog exclusion - Ignores notifications and popups to prevent false positives
* Small window support - Works correctly even with minimized browser windows
* Protection against multiple redirects - Prevents page reload loops
* Continuous operation - Works after every page navigation, no manual refresh needed
* Fully configurable - All settings in CONFIG object with detailed comments

## Installation

### Option 1: Without Extension (Quick Start)

1. Open any FACEIT match page (`/match/` or `/room/`)
2. Open browser console (`F12` or `Ctrl+Shift+J` / `Cmd+Option+J` on Mac)
3. Open `Faceit-Auto-Start.user.js` file and copy all code
4. **IMPORTANT**: Delete the first 9 lines (metadata starting with `// ==UserScript==` and ending with `// ==/UserScript==`)
5. Paste the remaining code (starting from line 11 with `(function() {`) into console and press `Enter`
6. Click the green "Включить авто-матч" button to activate

⚠️ **Note**: Script stops after page reload. You'll need to run it again.

### Option 2: With Tampermonkey/Greasemonkey (Recommended)

1. Install Tampermonkey or Greasemonkey browser extension
2. Download the `Faceit-Auto-Start.user.js` file
3. Click on the userscript file to install it in Tampermonkey
4. Navigate to any FACEIT match page
5. Click the "Включить авто-матч" button that appears in the top-right corner

✅ **Advantage**: Script works automatically on every page load.

## Usage

* Click the green "Включить авто-матч" button to activate the script
* Button changes color to indicate status:
  - **Green**: Script disabled
  - **Red**: Script active and monitoring
  - **Orange**: Match finished, redirecting
* Click the eye icon (👁️) on the button to hide it - a small eye icon will appear in its place
* Click the small eye icon to show the button again
* When match finishes, script automatically starts new match search
* When match is cancelled (AFK/abandonment), script starts new match search if enabled in CONFIG (`REDIRECT_ON_CANCELLED`)
* Script remembers state across page reloads
* Script works continuously - automatically detects finished matches even after redirects
* All settings can be customized in the `CONFIG` object at the top of the script

## Changes in Version

* **Full page scanning** - Checks entire page content, not just time element
* **Multi-game support** - Works with CS:GO, CS2, Dota 2 and other FACEIT games
* **Configurable cancellation redirect** - Option to enable/disable redirect on match cancellation (`REDIRECT_ON_CANCELLED`)
* **Complete configuration centralization** - All settings easily customizable in CONFIG object
* **Automatic match completion detection** - Monitors page content for finish status
* **Multi-language support** - Recognizes "finished", "завершен", "закончен", "окончен", "cancelled", "отменен", "отменён"
* **AFK cancellation detection** - Automatically detects and handles matches cancelled due to AFK players
* **State persistence** - Remembers enabled/disabled state across sessions using localStorage
* **Same-tab navigation** - Redirects in current tab, no popups
* **Configurable redirect delay** - Set custom delay before redirecting (in milliseconds, default: 0)
* **Comprehensive selectors** - Multiple time selectors for maximum compatibility
* **Small window support** - Works correctly with minimized browser windows
* **Modal exclusion** - Ignores notifications and popup dialogs to prevent false positives
* **Enhanced error handling** - Better recovery from various error states
* **Optimized performance** - Uses requestAnimationFrame for minimal CPU and memory usage
* **Multi-level element search** - Searches elements at different DOM levels for reliability
* **Protection against multiple redirects** - Prevents page reload loops
* **Continuous operation** - Works after every page navigation, no manual refresh needed
* **Comprehensive unit labeling** - All settings clearly marked with units (ms, px)

## GitHub

https://github.com/Gariloz/Faceit-Auto-Start

---

**Author:** Gariloz
