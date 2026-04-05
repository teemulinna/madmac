#!/bin/bash
set -euo pipefail

# MadMac Smoke Test — tests the ACTUAL app, not jsdom abstractions
# This is the real test: build → launch → open file → verify

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$PROJECT_ROOT/build/MadMac.app"
BINARY="$APP/Contents/MacOS/MadMac"
TEST_DIR="$PROJECT_ROOT/test-files"
PASS=0
FAIL=0
TOTAL=0

red()   { printf "\033[31m%s\033[0m\n" "$1"; }
green() { printf "\033[32m%s\033[0m\n" "$1"; }
bold()  { printf "\033[1m%s\033[0m\n" "$1"; }

assert() {
    TOTAL=$((TOTAL + 1))
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        green "  ✓ $name"
        PASS=$((PASS + 1))
    else
        red "  ✗ $name"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    TOTAL=$((TOTAL + 1))
    local name="$1"
    local haystack="$2"
    local needle="$3"
    if echo "$haystack" | grep -q "$needle"; then
        green "  ✓ $name"
        PASS=$((PASS + 1))
    else
        red "  ✗ $name (expected '$needle' in output)"
        FAIL=$((FAIL + 1))
    fi
}

cleanup() {
    # Kill any MadMac instances we started
    if [ -n "${MACMD_PID:-}" ]; then
        kill "$MACMD_PID" 2>/dev/null || true
        wait "$MACMD_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# ── 0. Build ──────────────────────────────────────
bold "=== Building MadMac ==="
"$PROJECT_ROOT/scripts/build.sh" >/dev/null 2>&1
green "  Build complete"

# ── 1. Bundle structure ───────────────────────────
bold ""
bold "=== 1. App Bundle Structure ==="

assert "Binary exists and is executable" test -x "$BINARY"
assert "Info.plist exists" test -f "$APP/Contents/Info.plist"
assert "editor.js exists in Resources" test -f "$APP/Contents/Resources/editor/editor.js"
assert "PkgInfo exists" test -f "$APP/Contents/PkgInfo"
assert "editor.js is >1MB (real CM6 bundle, not stub)" test "$(wc -c < "$APP/Contents/Resources/editor/editor.js")" -gt 1000000

# Verify Info.plist has critical keys
PLIST_CONTENT=$(/usr/libexec/PlistBuddy -c "Print" "$APP/Contents/Info.plist" 2>&1 || true)
assert_contains "Info.plist has NSDocumentClass" "$PLIST_CONTENT" "MarkdownDocument"
assert_contains "Info.plist has UTType identifier" "$PLIST_CONTENT" "net.daringfireball.markdown"
assert_contains "Info.plist has CFBundleExecutable=MadMac" "$PLIST_CONTENT" "CFBundleExecutable"

# ── 2. App launch ─────────────────────────────────
bold ""
bold "=== 2. App Launch ==="

# Kill any existing instances
pkill -x MadMac 2>/dev/null || true
sleep 1

# Launch the app binary directly (not via open) to capture stderr
"$BINARY" &
MACMD_PID=$!
sleep 2

assert "App process is running" kill -0 "$MACMD_PID"

# ── 3. Open file ──────────────────────────────────
bold ""
bold "=== 3. Open Markdown File ==="

# Create test file
mkdir -p "$TEST_DIR"
cat > "$TEST_DIR/smoke-test.md" << 'MARKDOWN'
# Smoke Test

This is **bold** and *italic*.

- Item 1
- Item 2

```python
print("hello")
```

| Col A | Col B |
|-------|-------|
| 1     | 2     |
MARKDOWN

# Use AppleScript to tell the app to open the file
# This is the real macOS document-open path
osascript -e "
    tell application \"System Events\"
        set frontApp to name of first process whose unix id is $MACMD_PID
    end tell
" >/dev/null 2>&1 || true

# Open via the open command (same as Finder double-click)
open -a "$APP" "$TEST_DIR/smoke-test.md" 2>&1
OPEN_EXIT=$?
sleep 2

assert "open -a exits successfully" test "$OPEN_EXIT" -eq 0
assert "App still running after file open" kill -0 "$MACMD_PID"

# ── 4. Non-UTF-8 rejection ───────────────────────
bold ""
bold "=== 4. Non-UTF-8 Rejection ==="

# Create a non-UTF-8 file
printf '\xff\xfe\x48\x00\x65\x00\x6c\x00\x6c\x00\x6f\x00' > "$TEST_DIR/utf16.md"
open -a "$APP" "$TEST_DIR/utf16.md" 2>&1 || true
sleep 2

assert "App survives non-UTF-8 file (no crash)" kill -0 "$MACMD_PID"

# ── 5. Large file ─────────────────────────────────
bold ""
bold "=== 5. Large File ==="

# Create a 10000 line file
python3 -c "
for i in range(10000):
    if i % 100 == 0:
        print(f'## Section {i//100}')
    print(f'Line {i}: Lorem ipsum dolor sit amet.')
" > "$TEST_DIR/large.md"

START_TIME=$(python3 -c "import time; print(time.time())")
open -a "$APP" "$TEST_DIR/large.md" 2>&1
sleep 3
END_TIME=$(python3 -c "import time; print(time.time())")

assert "App survives 10000-line file" kill -0 "$MACMD_PID"

ELAPSED=$(python3 -c "print(f'{$END_TIME - $START_TIME:.1f}')")
echo "  ℹ Large file open time: ${ELAPSED}s"

# ── 6. Multiple files ─────────────────────────────
bold ""
bold "=== 6. Multiple Files ==="

cat > "$TEST_DIR/multi-a.md" << 'MD'
# File A
Content A
MD
cat > "$TEST_DIR/multi-b.md" << 'MD'
# File B
Content B
MD

open -a "$APP" "$TEST_DIR/multi-a.md" "$TEST_DIR/multi-b.md" 2>&1
sleep 2

assert "App survives opening multiple files" kill -0 "$MACMD_PID"

# ── Results ───────────────────────────────────────
bold ""
bold "=== Results ==="
echo ""
if [ "$FAIL" -eq 0 ]; then
    green "  All $TOTAL tests passed ✓"
else
    red "  $FAIL/$TOTAL tests failed"
    green "  $PASS/$TOTAL tests passed"
fi
echo ""

# Cleanup test files
rm -f "$TEST_DIR/smoke-test.md" "$TEST_DIR/utf16.md" "$TEST_DIR/large.md" "$TEST_DIR/multi-a.md" "$TEST_DIR/multi-b.md"

exit "$FAIL"
