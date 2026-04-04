# macmd Testing Strategy

## Principle

**Every test must touch something real.** No test theatre.
If a test doesn't exercise the actual app, binary, or browser engine, it's not a real test.

---

## Test Layers

### Layer 1: Swift Document Model (`make test-swift`)
Compiled with `swiftc`, runs as a native binary. Tests the actual Swift code.

| Test | Verifies |
|------|----------|
| Valid UTF-8 read | MarkdownDocument.read() sets content correctly |
| Non-UTF-8 rejection | Throws error with "not valid UTF-8" message |
| Empty file | Content is empty string |
| Large file (10K lines) | No crash or memory issue |
| Data export | UTF-8 encoding correct |
| Unicode roundtrip | Finnish, Japanese, emoji survive read→write |
| Empty content export | Returns empty Data |
| readableTypes | Contains "net.daringfireball.markdown" |
| autosavesInPlace | Returns true |
| NSClassFromString | "MarkdownDocument" resolves (catches NSDocumentClass bug) |
| NSDocument subclass | MarkdownDocument inherits NSDocument |
| Read/data roundtrip | Byte-perfect markdown roundtrip |

**12 tests, all real.**

### Layer 2: Playwright WebKit (`make test-browser`)
Runs the built `editor.js` bundle in real WebKit (closest to WKWebView).

| Group | Tests | Verifies |
|-------|-------|----------|
| Bundle loading | 1 | No console errors, API exists |
| Editor creation | 3 | .cm-editor renders, content correct, reading mode read-only |
| Mode switching | 4 | Fluid mode editable, typing works, content preserved |
| Theme switching | 3 | Dark/light CSS colors applied correctly |
| Syntax highlighting | 3 | Heading/code/blockquote CSS classes present |
| Fluid Mode decorations | 8+1 | Heading/bold/italic/link syntax toggle, images, escape, content preservation. 1 fixme (multi-block timing bug) |
| Bridge messages | 4 | contentChanged, editorReady, modeChanged, themeChanged |
| Performance | 3 | 10K lines <2s, content accessible, scrolling stable |

**28 passed, 1 fixme (known bug), all in real WebKit.**

### Layer 3: App Integration (`make test-integration`)
Launches the real `macmd.app`, interacts via AppleScript/open command.

| Feature | Tests | Verifies |
|---------|-------|----------|
| File opening | 6 | Window titles, UTType, UTF-8, large files, multi-file |
| Reading mode | 1 | Default mode on open |
| File saving | 4 | Cmd+S writes to disk, UTF-8 preserved, LF preserved |
| Theme | 2 | Dark/light mode toggle survives |
| Fluid mode | 3 | Cmd+E toggle, menu item exists, 10x stress test |
| Menu structure | 6 | File/Edit/View menus with all expected items |
| App stability | 4 | Empty, whitespace, complex markdown, long lines |

**56 tests, all against the real app.**

### Layer 4: Smoke Test (`make test-smoke`)
Builds the app, verifies bundle structure, launches, opens files.

**14 tests, all against the real binary.**

### Layer 5: Unit Tests (supplement, not primary)
Fast tests for logic correctness. NOT a substitute for real tests.

- **Rust** (`make test-rust`): 23 tests — pulldown-cmark rendering logic
- **Vitest/jsdom** (`make test-editor`): 78 tests — CM6 extension logic
- **Fluid Mode jsdom**: 43 tests — state/decoration logic

**144 unit tests — fast feedback, not confidence.**

---

## Commands

```bash
# The real tests (what gives confidence):
make test-swift        # 12 tests — Swift binary
make test-browser      # 28 tests — real WebKit
make test-integration  # 56 tests — real macmd.app
make test-smoke        # 14 tests — build + launch

# Unit tests (fast feedback):
make test-rust         # 23 tests — Rust logic
make test-editor       # 78+43 tests — jsdom logic

# All unit + smoke:
make test              # Rust + jsdom + Swift + smoke

# Full validation (takes ~60s):
make test && make test-browser && make test-integration
```

---

## Known Issues

1. **Multi-block Cmd+click timing** (Playwright fixme): Fluid Mode's click handler
   uses setTimeout(0) which doesn't reliably sync with WebKit's decoration
   update cycle. Single-block editing works. Multi-block needs investigation.

---

## What We Learned

jsdom tests told us "78 tests pass" while the real app couldn't open files.
The NSDocumentClass bug was invisible to every unit test.
Now: every critical path has a test that touches the real artifact.
