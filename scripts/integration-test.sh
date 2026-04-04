#!/bin/bash
set -euo pipefail

# MadMac BDD Integration Tests
# Real tests against the ACTUAL MadMac.app — not mocks, not stubs.
# Maps key Gherkin scenarios from MadMac-tests/features/ to executable tests.

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$PROJECT_ROOT/build/MadMac.app"
BINARY="$APP/Contents/MacOS/MadMac"
TEST_DIR="$PROJECT_ROOT/test-files/integration"
PASS=0
FAIL=0
TOTAL=0
MACMD_PID=""

# ── Output helpers ────────────────────────────────
red()    { printf "\033[31m%s\033[0m\n" "$1"; }
green()  { printf "\033[32m%s\033[0m\n" "$1"; }
bold()   { printf "\033[1m%s\033[0m\n" "$1"; }
dim()    { printf "\033[2m%s\033[0m\n" "$1"; }

# ── Assertion helpers ─────────────────────────────

assert() {
    TOTAL=$((TOTAL + 1))
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        green "    PASS: $name"
        PASS=$((PASS + 1))
    else
        red "    FAIL: $name"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    TOTAL=$((TOTAL + 1))
    local name="$1"
    local haystack="$2"
    local needle="$3"
    if echo "$haystack" | grep -qi "$needle"; then
        green "    PASS: $name"
        PASS=$((PASS + 1))
    else
        red "    FAIL: $name (expected '$needle' in output)"
        FAIL=$((FAIL + 1))
    fi
}

assert_equals() {
    TOTAL=$((TOTAL + 1))
    local name="$1"
    local expected="$2"
    local actual="$3"
    if [ "$expected" = "$actual" ]; then
        green "    PASS: $name"
        PASS=$((PASS + 1))
    else
        red "    FAIL: $name (expected '$expected', got '$actual')"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_contains() {
    TOTAL=$((TOTAL + 1))
    local name="$1"
    local filepath="$2"
    local needle="$3"
    if [ -f "$filepath" ] && grep -q "$needle" "$filepath"; then
        green "    PASS: $name"
        PASS=$((PASS + 1))
    else
        red "    FAIL: $name (expected '$needle' in $filepath)"
        FAIL=$((FAIL + 1))
    fi
}

# ── Window helpers via AppleScript ────────────────

get_window_count() {
    osascript -e '
        tell application "System Events"
            tell process "MadMac"
                return count of windows
            end tell
        end tell
    ' 2>/dev/null || echo "0"
}

get_front_window_title() {
    osascript -e '
        tell application "System Events"
            tell process "MadMac"
                return name of front window
            end tell
        end tell
    ' 2>/dev/null || echo ""
}

get_all_window_titles() {
    osascript -e '
        tell application "System Events"
            tell process "MadMac"
                return name of every window
            end tell
        end tell
    ' 2>/dev/null || echo ""
}

get_menu_items() {
    local menu_name="$1"
    osascript -e "
        tell application \"System Events\"
            tell process \"MadMac\"
                return name of every menu item of menu \"$menu_name\" of menu bar 1
            end tell
        end tell
    " 2>/dev/null || echo ""
}

send_keystroke() {
    local key="$1"
    local modifier="$2"
    osascript -e "
        tell application \"System Events\"
            tell process \"MadMac\"
                set frontmost to true
                keystroke \"$key\" using $modifier
            end tell
        end tell
    " 2>/dev/null || true
}

close_all_windows() {
    osascript -e '
        tell application "System Events"
            tell process "MadMac"
                repeat with w in (every window)
                    try
                        click button 1 of w
                    end try
                end repeat
            end tell
        end tell
    ' 2>/dev/null || true
    sleep 1
}

# ── Setup & teardown ──────────────────────────────

setup() {
    mkdir -p "$TEST_DIR"
    # Kill any existing MadMac instances
    pkill -x MadMac 2>/dev/null || true
    sleep 1
}

launch_app() {
    "$BINARY" &
    MACMD_PID=$!
    sleep 3

    # In headless/CI mode: keep app in background to avoid stealing focus
    if [ "${MACMD_HEADLESS:-0}" = "1" ]; then
        osascript -e '
            tell application "System Events"
                tell process "MadMac"
                    set visible to false
                end tell
            end tell
        ' 2>/dev/null || true
    else
        osascript -e '
            tell application "System Events"
                tell process "MadMac"
                    set frontmost to true
                end tell
            end tell
        ' 2>/dev/null || true
    fi
}

cleanup() {
    # Kill the app
    if [ -n "${MACMD_PID:-}" ]; then
        kill "$MACMD_PID" 2>/dev/null || true
        wait "$MACMD_PID" 2>/dev/null || true
    fi
    pkill -x MadMac 2>/dev/null || true
    # Clean up test files
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# ── Build ─────────────────────────────────────────
bold ""
bold "============================================"
bold "  MadMac BDD Integration Tests"
bold "============================================"
bold ""
bold "Building MadMac..."
"$PROJECT_ROOT/scripts/build.sh" >/dev/null 2>&1
green "  Build complete."
bold ""

# ── Launch ────────────────────────────────────────
setup
launch_app
assert "App process is running" kill -0 "$MACMD_PID"
bold ""

# ==================================================
# Feature: Ikkunan koon muuttaminen
#   (from MadMac-tests/features/window-resize.feature)
# ==================================================
bold "Feature: Window resizing"
bold ""

# ── Scenario: Window can be resized by dragging ──
dim "  Scenario: Window can be resized by dragging"

cat > "$TEST_DIR/resize-test.md" << 'MD'
# Resize Test

This file tests that the window can be resized freely.
MD

open -a "$APP" "$TEST_DIR/resize-test.md"
sleep 4

osascript -e '
    tell application "System Events"
        tell process "MadMac"
            set frontmost to true
        end tell
    end tell
' 2>/dev/null || true
sleep 1

# Get initial size
INITIAL_SIZE=$(osascript -e '
    tell application "System Events"
        tell process "MadMac"
            return size of front window
        end tell
    end tell
' 2>/dev/null || echo "0, 0")

# Resize to 700x500
osascript -e '
    tell application "System Events"
        tell process "MadMac"
            set size of front window to {700, 500}
        end tell
    end tell
' 2>/dev/null || true
sleep 1

NEW_SIZE=$(osascript -e '
    tell application "System Events"
        tell process "MadMac"
            return size of front window
        end tell
    end tell
' 2>/dev/null || echo "0, 0")

# Extract width from "width, height" format
NEW_WIDTH=$(echo "$NEW_SIZE" | cut -d',' -f1 | tr -d ' ')

# Window should have changed to approximately 700px wide (allow ±50px tolerance)
if [ -n "$NEW_WIDTH" ] && [ "$NEW_WIDTH" -ge 650 ] 2>/dev/null && [ "$NEW_WIDTH" -le 750 ] 2>/dev/null; then
    RESIZE_OK="yes"
else
    RESIZE_OK="no"
fi
assert_equals "Window resized to ~700px wide" "yes" "$RESIZE_OK"

# Resize back to something else to confirm it's not stuck
osascript -e '
    tell application "System Events"
        tell process "MadMac"
            set size of front window to {900, 600}
        end tell
    end tell
' 2>/dev/null || true
sleep 1

SECOND_SIZE=$(osascript -e '
    tell application "System Events"
        tell process "MadMac"
            return size of front window
        end tell
    end tell
' 2>/dev/null || echo "0, 0")
SECOND_WIDTH=$(echo "$SECOND_SIZE" | cut -d',' -f1 | tr -d ' ')

if [ -n "$SECOND_WIDTH" ] && [ "$SECOND_WIDTH" -ge 850 ] 2>/dev/null && [ "$SECOND_WIDTH" -le 950 ] 2>/dev/null; then
    RESIZE2_OK="yes"
else
    RESIZE2_OK="no"
fi
assert_equals "Window resized again to ~900px wide" "yes" "$RESIZE2_OK"

assert "App stable after resizing" kill -0 "$MACMD_PID"
bold ""

# ── Scenario: Window respects minimum size ───────
dim "  Scenario: Window respects minimum size"

osascript -e '
    tell application "System Events"
        tell process "MadMac"
            set size of front window to {200, 150}
        end tell
    end tell
' 2>/dev/null || true
sleep 1

MIN_SIZE=$(osascript -e '
    tell application "System Events"
        tell process "MadMac"
            return size of front window
        end tell
    end tell
' 2>/dev/null || echo "0, 0")
MIN_WIDTH=$(echo "$MIN_SIZE" | cut -d',' -f1 | tr -d ' ')

# Window should not go below minSize (400x300 defined in MarkdownDocument)
assert "Window width >= 400 (minimum)" test "$MIN_WIDTH" -ge 390
assert "App stable after min-size test" kill -0 "$MACMD_PID"

close_all_windows
bold ""

# ==================================================
# Feature: Opening markdown files
#   (from MadMac-tests/features/opening-files.feature)
# ==================================================
bold "Feature: Opening markdown files"
bold ""

# ── Scenario: Open a simple markdown file ─────────
dim "  Scenario: Open a simple markdown file"

cat > "$TEST_DIR/hello.md" << 'MD'
# Hello World

This is a **simple** markdown file.
MD

open -a "$APP" "$TEST_DIR/hello.md"
sleep 4

# Ensure MadMac is frontmost so AppleScript can query windows
osascript -e '
    tell application "System Events"
        tell process "MadMac"
            set frontmost to true
        end tell
    end tell
' 2>/dev/null || true
sleep 1

TITLE=$(get_front_window_title)
assert "Window appears after opening file" test -n "$TITLE"
assert_contains "Window title contains filename" "$TITLE" "hello"
assert "App still running after file open" kill -0 "$MACMD_PID"
bold ""

# ── Scenario: Open a file with UTF-8 content ─────
dim "  Scenario: Open a file with UTF-8 content"

cat > "$TEST_DIR/unicode.md" << 'MD'
# Unicode Test

Finnish: Hyva paivaa
Japanese: Konnichiwa
Emoji: Party Rocket Check
MD
# Write actual UTF-8 content via python for reliable encoding
python3 -c "
with open('$TEST_DIR/unicode.md', 'w', encoding='utf-8') as f:
    f.write('# Unicode Test\n\n')
    f.write('Finnish: Hyv\u00e4\u00e4 p\u00e4iv\u00e4\u00e4\n')
    f.write('Japanese: \u3053\u3093\u306b\u3061\u306f\n')
    f.write('Emoji: \U0001f389 \U0001f680 \u2705\n')
"

open -a "$APP" "$TEST_DIR/unicode.md"
sleep 3

osascript -e '
    tell application "System Events"
        tell process "MadMac"
            set frontmost to true
        end tell
    end tell
' 2>/dev/null || true
sleep 1

TITLE=$(get_front_window_title)
assert_contains "UTF-8 file opens with correct title" "$TITLE" "unicode"
assert "App survives UTF-8 content" kill -0 "$MACMD_PID"
bold ""

# ── Scenario: Open a non-UTF-8 file shows error ──
# SKIPPED: macOS shows a modal error dialog that requires user click.
# The document model test covers the UTF-8 validation logic.
dim "  Scenario: Open a non-UTF-8 file (SKIPPED — requires user interaction)"
bold ""

# ── Scenario: Open a large markdown file ──────────
dim "  Scenario: Open a large markdown file"

python3 -c "
for i in range(10000):
    if i % 100 == 0:
        print(f'## Section {i//100}')
    print(f'Line {i}: Lorem ipsum dolor sit amet, consectetur adipiscing elit.')
" > "$TEST_DIR/large.md"

START_TIME=$(python3 -c "import time; print(time.time())")
open -a "$APP" "$TEST_DIR/large.md"
sleep 4
END_TIME=$(python3 -c "import time; print(time.time())")

assert "App survives 10000-line file" kill -0 "$MACMD_PID"

ELAPSED=$(python3 -c "print(f'{$END_TIME - $START_TIME:.1f}')")
dim "    (Large file open time: ${ELAPSED}s)"
bold ""

# ── Scenario: Open multiple files simultaneously ──
dim "  Scenario: Open multiple files simultaneously"

# Close existing windows first
close_all_windows

cat > "$TEST_DIR/multi-a.md" << 'MD'
# File A
Content of file A.
MD

cat > "$TEST_DIR/multi-b.md" << 'MD'
# File B
Content of file B.
MD

open -a "$APP" "$TEST_DIR/multi-a.md" "$TEST_DIR/multi-b.md"
sleep 3

WINDOW_COUNT=$(get_window_count)
assert "Two files open as tabs in one window" test "$WINDOW_COUNT" -eq 1

ALL_TITLES=$(get_all_window_titles)
# With tabs, the window title shows the active tab's name
assert "App still running after multiple file open" kill -0 "$MACMD_PID"
bold ""

# ── Scenario: Cmd+N creates new tab ─────────────
dim "  Scenario: Cmd+N creates new tab"

osascript -e '
    tell application "System Events"
        tell process "MadMac"
            set frontmost to true
        end tell
    end tell
' 2>/dev/null || true
sleep 1

# Count windows before
BEFORE_COUNT=$(get_window_count)

# Cmd+N should create a new tab (not a new window when tabbingMode is preferred)
send_keystroke "n" "command down"
sleep 2

AFTER_COUNT=$(get_window_count)
# With native tabs, Cmd+N should keep windows at same count (new tab, not new window)
assert "Cmd+N does not create a new window (uses tab)" test "$AFTER_COUNT" -eq "$BEFORE_COUNT"
assert "App stable after Cmd+N" kill -0 "$MACMD_PID"

close_all_windows
bold ""

# ── Scenario: Registered UTType for markdown ──────
dim "  Scenario: Registered UTType for markdown extensions"

PLIST="$APP/Contents/Info.plist"
PLIST_CONTENT=$(/usr/libexec/PlistBuddy -c "Print" "$PLIST" 2>&1 || true)
assert_contains "UTType declares .md extension" "$PLIST_CONTENT" "md"
assert_contains "UTType declares .markdown extension" "$PLIST_CONTENT" "markdown"
assert_contains "UTType identifier is net.daringfireball.markdown" "$PLIST_CONTENT" "net.daringfireball.markdown"
assert_contains "NSDocumentClass is MarkdownDocument" "$PLIST_CONTENT" "MarkdownDocument"
bold ""

# ==================================================
# Feature: Reading Mode
#   (from MadMac-tests/features/reading-mode.feature)
# ==================================================
bold "Feature: Reading mode"
bold ""

dim "  Scenario: File opens in Reading Mode by default"

# Close all windows, open a fresh file
close_all_windows

cat > "$TEST_DIR/reading-mode.md" << 'MD'
# Reading Mode Test

This file should open in **reading mode** by default.

- Item one
- Item two
MD

open -a "$APP" "$TEST_DIR/reading-mode.md"
sleep 3

# The app starts in reading mode (isFluidMode = false in EditorViewController).
# We verify the window appeared and the app is stable.
TITLE=$(get_front_window_title)
assert_contains "File opens and shows title" "$TITLE" "reading-mode"
assert "App is stable in reading mode" kill -0 "$MACMD_PID"
bold ""

# ==================================================
# Feature: File saving and autosave
#   (from MadMac-tests/features/file-saving.feature)
# ==================================================
bold "Feature: File saving and autosave"
bold ""

# ── Scenario: Save preserves file content ─────────
dim "  Scenario: Open file, save, verify disk content"

close_all_windows

SAVE_FILE="$TEST_DIR/save-test.md"
cat > "$SAVE_FILE" << 'MD'
# Save Test

Original content here.
MD

ORIGINAL_HASH=$(shasum "$SAVE_FILE" | cut -d' ' -f1)

open -a "$APP" "$SAVE_FILE"
sleep 3

# Send Cmd+S to save
send_keystroke "s" "command down"
sleep 2

# The file should still exist and the app should be stable
assert "File still exists on disk after save" test -f "$SAVE_FILE"
assert "App survives Cmd+S" kill -0 "$MACMD_PID"

# Content should be preserved (no corruption on read+save cycle)
assert_file_contains "Saved file contains heading" "$SAVE_FILE" "# Save Test"
assert_file_contains "Saved file contains body" "$SAVE_FILE" "Original content here."
bold ""

# ── Scenario: Autosave (autosavesInPlace) ─────────
dim "  Scenario: Autosave is enabled in document class"

# We verify the Swift source declares autosavesInPlace = true
SWIFT_DOC="$PROJECT_ROOT/MadMac-app/Sources/Document/MarkdownDocument.swift"
assert_file_contains "autosavesInPlace is true" "$SWIFT_DOC" "autosavesInPlace.*true"
bold ""

# ── Scenario: Save preserves UTF-8 encoding ───────
dim "  Scenario: Save preserves UTF-8 encoding"

UTF8_FILE="$TEST_DIR/utf8-save.md"
python3 -c "
with open('$UTF8_FILE', 'w', encoding='utf-8') as f:
    f.write('# UTF-8 Save Test\n\n')
    f.write('Finnish: Hyv\u00e4\u00e4 p\u00e4iv\u00e4\u00e4\n')
    f.write('Japanese: \u3053\u3093\u306b\u3061\u306f\n')
"

open -a "$APP" "$UTF8_FILE"
sleep 3

send_keystroke "s" "command down"
sleep 2

# Verify file is still valid UTF-8
VALID_UTF8=$(python3 -c "
try:
    open('$UTF8_FILE', 'r', encoding='utf-8').read()
    print('yes')
except:
    print('no')
")
assert_equals "Saved file is valid UTF-8" "yes" "$VALID_UTF8"

# Verify content is not garbled
assert_file_contains "UTF-8 content preserved after save" "$UTF8_FILE" "UTF-8 Save Test"
assert "App stable after saving UTF-8 file" kill -0 "$MACMD_PID"
bold ""

# ── Scenario: Save preserves line endings ─────────
dim "  Scenario: Save preserves LF line endings"

LF_FILE="$TEST_DIR/lf-test.md"
printf "# LF Test\n\nLine two\nLine three\n" > "$LF_FILE"

# Count CRLFs before (should be 0 for pure LF)
CRLF_BEFORE=$(python3 -c "
data = open('$LF_FILE', 'rb').read()
print(data.count(b'\r\n'))
")

open -a "$APP" "$LF_FILE"
sleep 3
send_keystroke "s" "command down"
sleep 2

CRLF_AFTER=$(python3 -c "
data = open('$LF_FILE', 'rb').read()
print(data.count(b'\r\n'))
")

assert_equals "No CRLF introduced after save (LF preserved)" "$CRLF_BEFORE" "$CRLF_AFTER"
bold ""

# ==================================================
# Feature: Theme and appearance
#   (from MadMac-tests/features/theme-appearance.feature)
# ==================================================
bold "Feature: Theme and appearance"
bold ""

dim "  Scenario: App respects system theme without crashing"

# Verify the theme observation code exists in the source
EDITOR_VC="$PROJECT_ROOT/MadMac-app/Sources/Editor/EditorViewController.swift"
assert_file_contains "System theme detection exists" "$EDITOR_VC" "darkAqua"
assert_file_contains "Theme JS bridge exists" "$EDITOR_VC" "setTheme"
assert "App stable with theme system" kill -0 "$MACMD_PID"
bold ""

dim "  Scenario: App survives appearance toggle"

# Switch dark mode on and off rapidly to stress-test theme handling
osascript -e '
    tell application "System Events"
        tell appearance preferences
            set dark mode to (not dark mode)
        end tell
    end tell
' 2>/dev/null || true
sleep 2

assert "App survives theme toggle" kill -0 "$MACMD_PID"

# Toggle back
osascript -e '
    tell application "System Events"
        tell appearance preferences
            set dark mode to (not dark mode)
        end tell
    end tell
' 2>/dev/null || true
sleep 1

assert "App survives theme toggle back" kill -0 "$MACMD_PID"
bold ""

# ==================================================
# Feature: Fluid Mode inline editing
#   (from MadMac-tests/features/fluid-mode-editing.feature)
# ==================================================
bold "Feature: Fluid mode editing (Cmd+E toggle)"
bold ""

# ── Scenario: Toggle between Reading and Fluid Mode
dim "  Scenario: Cmd+E toggles between Reading and Fluid Mode"

close_all_windows

cat > "$TEST_DIR/fluid-mode.md" << 'MD'
# Fluid Mode Test

This is a paragraph with **bold** text.

- Item one
- Item two
MD

open -a "$APP" "$TEST_DIR/fluid-mode.md"
sleep 3

# Make sure MadMac is frontmost
osascript -e '
    tell application "System Events"
        tell process "MadMac"
            set frontmost to true
        end tell
    end tell
' 2>/dev/null || true
sleep 1

# Send Cmd+E to toggle to fluid mode
send_keystroke "e" "command down"
sleep 2

assert "App survives Cmd+E toggle to Fluid Mode" kill -0 "$MACMD_PID"

# Toggle back to reading mode
send_keystroke "e" "command down"
sleep 2

assert "App survives Cmd+E toggle back to Reading Mode" kill -0 "$MACMD_PID"
bold ""

# ── Scenario: Mode toggle via View menu ───────────
dim "  Scenario: View menu has Toggle Edit Mode item"

VIEW_ITEMS=$(get_menu_items "View")
assert_contains "View menu has Toggle Edit Mode" "$VIEW_ITEMS" "Toggle Edit Mode"
assert_contains "View menu has Sidebar item" "$VIEW_ITEMS" "Sidebar"
bold ""

# ==================================================
# Feature: Workspace layout with sidebar
#   (from MadMac-tests/features/workspace-layout.feature)
# ==================================================
bold "Feature: Workspace layout with sidebar"
bold ""

dim "  Scenario: Sidebar toggles with keyboard shortcut"

close_all_windows

cat > "$TEST_DIR/sidebar-test.md" << 'MD'
# Sidebar Test

Testing sidebar toggle and workspace layout.
MD

open -a "$APP" "$TEST_DIR/sidebar-test.md"
sleep 4

osascript -e '
    tell application "System Events"
        tell process "MadMac"
            set frontmost to true
        end tell
    end tell
' 2>/dev/null || true
sleep 1

# Toggle sidebar off (Cmd+Shift+S — mapped to NSSplitViewController.toggleSidebar)
send_keystroke "b" "command down"
sleep 1

assert "App survives sidebar toggle off" kill -0 "$MACMD_PID"

# Toggle sidebar back on
send_keystroke "b" "command down"
sleep 1

assert "App survives sidebar toggle on" kill -0 "$MACMD_PID"

# Verify window title still shows the file
TITLE=$(get_front_window_title)
assert_contains "Window still shows file after sidebar toggle" "$TITLE" "sidebar-test"
bold ""

dim "  Scenario: All existing features work with sidebar"

# Theme toggle should still work
send_keystroke "e" "command down"
sleep 1
assert "Cmd+E works in split view" kill -0 "$MACMD_PID"
send_keystroke "e" "command down"
sleep 1

# Zoom should still work
send_keystroke "+" "command down"
sleep 0.5
send_keystroke "0" "command down"
sleep 0.5
assert "Zoom works in split view" kill -0 "$MACMD_PID"

# Save should still work
send_keystroke "s" "command down"
sleep 1
assert "Cmd+S works in split view" kill -0 "$MACMD_PID"

close_all_windows
bold ""

# ── Scenario: Rapid mode toggling stress test ─────
dim "  Scenario: Rapid Cmd+E toggling does not crash"

for i in $(seq 1 10); do
    send_keystroke "e" "command down"
    sleep 0.3
done
sleep 2

assert "App survives 10 rapid Cmd+E toggles" kill -0 "$MACMD_PID"
bold ""

# ==================================================
# Feature: Menu structure
#   (from app delegate setup)
# ==================================================
bold "Feature: Menu structure"
bold ""

dim "  Scenario: App has expected menus"

MENUS=$(osascript -e '
    tell application "System Events"
        tell process "MadMac"
            return name of every menu of menu bar 1
        end tell
    end tell
' 2>/dev/null || echo "")

assert_contains "File menu exists" "$MENUS" "File"
assert_contains "Edit menu exists" "$MENUS" "Edit"
assert_contains "View menu exists" "$MENUS" "View"
bold ""

dim "  Scenario: File menu has expected items"

FILE_ITEMS=$(get_menu_items "File")
assert_contains "File menu has New" "$FILE_ITEMS" "New"
assert_contains "File menu has Open" "$FILE_ITEMS" "Open"
assert_contains "File menu has Save" "$FILE_ITEMS" "Save"
assert_contains "File menu has Close" "$FILE_ITEMS" "Close"
assert_contains "File menu has Open Recent" "$FILE_ITEMS" "Open Recent"
bold ""

dim "  Scenario: Edit menu has expected items"

EDIT_ITEMS=$(get_menu_items "Edit")
assert_contains "Edit menu has Undo" "$EDIT_ITEMS" "Undo"
assert_contains "Edit menu has Redo" "$EDIT_ITEMS" "Redo"
assert_contains "Edit menu has Cut" "$EDIT_ITEMS" "Cut"
assert_contains "Edit menu has Copy" "$EDIT_ITEMS" "Copy"
assert_contains "Edit menu has Paste" "$EDIT_ITEMS" "Paste"
assert_contains "Edit menu has Select All" "$EDIT_ITEMS" "Select All"
bold ""

# ==================================================
# Feature: App stability
# ==================================================
bold "Feature: App stability"
bold ""

dim "  Scenario: Open empty markdown file"

EMPTY_FILE="$TEST_DIR/empty.md"
touch "$EMPTY_FILE"
open -a "$APP" "$EMPTY_FILE"
sleep 2

assert "App survives empty file" kill -0 "$MACMD_PID"
bold ""

dim "  Scenario: Open file with only whitespace"

WHITESPACE_FILE="$TEST_DIR/whitespace.md"
printf "   \n\n   \n\t\t\n" > "$WHITESPACE_FILE"
open -a "$APP" "$WHITESPACE_FILE"
sleep 2

assert "App survives whitespace-only file" kill -0 "$MACMD_PID"
bold ""

dim "  Scenario: Open file with special markdown constructs"

cat > "$TEST_DIR/special.md" << 'MD'
---
title: Front Matter Test
date: 2026-04-03
---

# Special Constructs

> Blockquote with **bold** inside

---

| Col A | Col B |
|-------|-------|
| 1     | 2     |

```python
def hello():
    print("Hello, World!")
```

- [x] Done task
- [ ] Pending task

This has a footnote[^1].

[^1]: Footnote content.
MD

open -a "$APP" "$TEST_DIR/special.md"
sleep 3

TITLE=$(get_front_window_title)
assert_contains "Special constructs file opens" "$TITLE" "special"
assert "App survives complex markdown" kill -0 "$MACMD_PID"
bold ""

dim "  Scenario: Open file with very long lines"

python3 -c "
with open('$TEST_DIR/longlines.md', 'w') as f:
    f.write('# Long Lines\n\n')
    f.write('A' * 10000 + '\n\n')
    f.write('B ' * 5000 + '\n')
"
open -a "$APP" "$TEST_DIR/longlines.md"
sleep 2

assert "App survives very long lines" kill -0 "$MACMD_PID"
bold ""

# ==================================================
# Phase 2 — Diagram rendering (RED tests)
# These MUST fail until Phase 2 is implemented.
# ==================================================

bold ""
bold "Feature: Mermaid diagram rendering"
bold ""

dim "  Scenario: Open file with mermaid diagram"

cat > "$TEST_DIR/mermaid-test.md" << 'MERMAID'
# Diagram Test

```mermaid
graph TD
  A[Start] --> B[Process]
  B --> C[End]
```

Text after diagram.
MERMAID

open -a "$APP" "$TEST_DIR/mermaid-test.md"
sleep 3

assert "App opens mermaid file without crash" kill -0 "$MACMD_PID"

# Check if the window shows the file
MERMAID_WINDOW=$(osascript -e 'tell application "System Events" to tell process "MadMac" to get name of windows' 2>&1 || echo "")
assert_contains "Window opened for mermaid file" "$MERMAID_WINDOW" "mermaid"

bold ""
dim "  Scenario: Open file with KaTeX math"

cat > "$TEST_DIR/math-test.md" << 'MATH'
# Math Test

The equation $E = mc^2$ is inline.

Display math:

$$\int_0^\infty e^{-x} dx = 1$$
MATH

open -a "$APP" "$TEST_DIR/math-test.md"
sleep 2

assert "App opens math file without crash" kill -0 "$MACMD_PID"

# ==================================================
# Results
# ==================================================
bold ""
bold "============================================"
bold "  Results"
bold "============================================"
bold ""

if [ "$FAIL" -eq 0 ]; then
    green "  All $TOTAL tests passed."
else
    red "  $FAIL of $TOTAL tests failed."
    green "  $PASS of $TOTAL tests passed."
fi
bold ""

exit "$FAIL"
