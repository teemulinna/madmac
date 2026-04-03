# macmd — The Native macOS Markdown Editor

> A fast, native macOS markdown editor with seamless inline rendering,
> first-class diagram support, and an editing experience so intuitive
> it feels like the file format was designed for it.

## Vision

Fill the market gap that no existing editor addresses: **native performance +
Typora-level inline WYSIWYG + 100% Mermaid + 28 diagram languages + zero config**.

## Core Principles

1. **One pane, zero config** — Opens instantly, works perfectly. No split panes, no setup wizard.
2. **Fluid Mode** — Our innovation: seamless animated transitions between rendered and editable states.
3. **Diagrams as first-class citizens** — Not a plugin, not an afterthought. Native, fast, inline.
4. **Native macOS citizen** — Feels like Apple made it. Finder integration, QuickLook, Spotlight.
5. **Keyboard-first, mouse-friendly** — Everything via keyboard. Command palette for discovery.

---

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                 Swift / AppKit Shell                  │
│  Window management, menus, preferences, Finder UTType │
│  QuickLook extension, Spotlight importer, Services    │
├──────────────────────────────────────────────────────┤
│              WKWebView (Editor Surface)               │
│  ┌──────────────────────────────────────────────┐    │
│  │           CodeMirror 6 Core                   │    │
│  │  ┌──────────────┐  ┌─────────────────────┐   │    │
│  │  │ Fluid Mode   │  │ Diagram Widget      │   │    │
│  │  │ Extension    │  │ Extension           │   │    │
│  │  │ (inline      │  │ (render/edit/cache) │   │    │
│  │  │  WYSIWYG)    │  │                     │   │    │
│  │  └──────────────┘  └─────────────────────┘   │    │
│  │  ┌──────────────┐  ┌─────────────────────┐   │    │
│  │  │ KaTeX Math   │  │ Smart Paste /       │   │    │
│  │  │ Extension    │  │ Table Editor        │   │    │
│  │  └──────────────┘  └─────────────────────┘   │    │
│  └──────────────────────────────────────────────┘    │
├──────────────────────────────────────────────────────┤
│            Swift ←→ Rust Bridge (swift-bridge)        │
├──────────────────────────────────────────────────────┤
│                    Rust Core                          │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │ pulldown-cmark│  │ mmdr/selkie  │  │ resvg      │ │
│  │ (streaming   │  │ (native      │  │ (SVG→PNG   │ │
│  │  MD parser)  │  │  Mermaid,    │  │  render)   │ │
│  │              │  │  400x faster)│  │            │ │
│  ├──────────────┤  ├──────────────┤  ├────────────┤ │
│  │ comrak       │  │ Kroki client │  │ tree-sitter│ │
│  │ (full GFM    │  │ (28+ diagram │  │ (syntax    │ │
│  │  AST, export)│  │  languages)  │  │  highlight)│ │
│  ├──────────────┤  ├──────────────┤  ├────────────┤ │
│  │ ropey        │  │ Content-hash │  │ Export     │ │
│  │ (text buffer)│  │ diagram cache│  │ (PDF/HTML/ │ │
│  │              │  │              │  │  DOCX)     │ │
│  └──────────────┘  └──────────────┘  └────────────┘ │
└──────────────────────────────────────────────────────┘
```

### Why This Architecture

| Decision | Alternative Considered | Why We Chose This |
|----------|----------------------|-------------------|
| CodeMirror 6 in WKWebView | TextKit 2 / NSTextView | Even TextKit experts (MarkEdit, STTextView) abandoned it. CM6 proven for inline WYSIWYG. |
| Swift shell + Rust core | Pure Rust (egui/GPUI) | Native macOS feel requires AppKit. Rust for computation, Swift for platform. |
| swift-bridge FFI | UniFFI, cbindgen | Zero serialization overhead, macOS-only so no need for UniFFI's multi-language support. |
| mmdr for Mermaid | mermaid.js only | 400-700x faster. Native Rust. No browser dependency for diagram rendering. |
| pulldown-cmark (edit) + comrak (export) | Single parser | Streaming parser for real-time; AST parser for export transformations. |
| Kroki for other diagrams | Individual integrations | One HTTP API covers PlantUML, D2, Graphviz, and 25+ more languages. |

---

## Fluid Mode — The Innovation

Our editing paradigm, informed by cognitive load research (Sweller 1988,
Mayer's Spatial Contiguity Principle):

### States

```
┌─────────────────┐    click/Enter     ┌──────────────────┐
│   RENDERED      │ ─────────────────→ │   EDITING        │
│                 │                     │                  │
│ • Heading shown │    Escape/blur      │ • # Heading      │
│   as styled     │ ←───────────────── │   shown as raw   │
│ • Links shown   │    (animated        │ • [text](url)    │
│   as clickable  │     morph)          │   shown as raw   │
│ • Diagrams as   │                     │ • Diagram source │
│   rendered SVG  │                     │   with live      │
│ • Math as       │                     │   preview below  │
│   rendered eq.  │                     │                  │
└─────────────────┘                     └──────────────────┘
```

### How It Differs from Existing Approaches

| Feature | Typora | Obsidian Live Preview | macmd Fluid Mode |
|---------|--------|----------------------|------------------|
| Transition | Instant, jarring | Instant | Animated morph |
| Scope | Block-level | Line-level | Block-level, multi-select |
| Multiple editing blocks | No | No | Yes |
| Diagram editing | Code block only | Code block only | Inline source + live preview |
| Extensibility | None | CM6 plugins | CM6 plugins + Rust extensions |

### Implementation (CM6 Extensions)

```
FluidMode Extension
├── StateField: tracks which blocks are in "editing" state
├── ViewPlugin: handles cursor enter/leave events per block
├── Decoration.replace(): hides markdown syntax in rendered blocks
├── Decoration.widget(): inserts rendered HTML for complex elements
├── CSS transitions: animated morph between states (~200ms ease)
└── DiagramWidget: special handling for fenced code blocks
    ├── Rendered state: shows SVG from Rust renderer
    ├── Editing state: shows source + live SVG below
    └── Cache: content-hash → SVG (survives app restart)
```

---

## Supported Formats

### Markdown
- CommonMark 0.31.2 (full spec)
- GitHub Flavored Markdown (tables, task lists, strikethrough, autolinks)
- Footnotes, definition lists, front matter (YAML/TOML)
- KaTeX math (`$inline$` and `$$display$$`)
- Smart typography (quotes, dashes, ellipses)

### Diagram Languages (Tier 1 — Native)
- **Mermaid** (all 23+ types): flowchart, sequence, class, state, ER, gantt, pie,
  mindmap, timeline, sankey, xy-chart, block, architecture, and more
  → Rendered natively via mmdr in Rust (2-6ms per diagram)

### Diagram Languages (Tier 2 — Via Kroki)
- PlantUML, D2, Graphviz/DOT, Ditaa, Excalidraw, WaveDrom, Vega/Vega-Lite,
  Pikchr, BPMN, DBML, Nomnoml, SvgBob, Structurizr, TikZ, Erd, Typograms,
  Symbolator, WireViz, ByteField, BlockDiag/SeqDiag/ActDiag/NwDiag
  → 28+ languages via single Kroki HTTP API

---

## Finder Integration

### UTType Registration (Info.plist)
```xml
<key>CFBundleDocumentTypes</key>
<array>
  <dict>
    <key>CFBundleTypeName</key>      <string>Markdown Document</string>
    <key>CFBundleTypeRole</key>      <string>Editor</string>
    <key>LSHandlerRank</key>         <string>Default</string>
    <key>LSItemContentTypes</key>
    <array>
      <string>net.daringfireball.markdown</string>
    </array>
  </dict>
</array>
```

### Extensions
- **QuickLook**: Preview .md files in Finder (rendered, with diagrams)
- **Spotlight Importer**: Index markdown content for search
- **Share Extension**: Create .md from shared content
- **Finder Extension**: "New Markdown File" context menu item

---

## Performance Targets

| Metric | Target | SOTA Comparison |
|--------|--------|-----------------|
| App startup | < 500ms | Obsidian: 2-5s, MarkEdit: ~300ms |
| File open (1MB) | < 100ms | MarkEdit: ~100ms |
| Memory (idle) | < 80MB | Obsidian: 300-500MB, MarkEdit: ~50MB |
| Mermaid render | < 10ms | mermaid.js: 100-500ms, mmdr: 2-6ms |
| Typing latency | < 16ms | Imperceptible at 60fps |
| Install size | < 20MB | Obsidian: 250MB, MarkEdit: 4MB |
| Export to PDF | < 2s | — |

### Optimization Strategies
- **Two-tier debounce**: 50ms for text re-render, 300ms for diagram re-render
- **Content-hash caching**: Diagram source → SVG cached on disk; skip re-render on unchanged
- **Lazy rendering**: IntersectionObserver for off-screen diagrams
- **WKWebView warm-up**: Pre-initialize at app launch
- **Incremental parsing**: pulldown-cmark streaming + tree-sitter incremental

---

## UX Delighters

These are the moments that make users fall in love:

1. **Magic heading** — Type `# Hello`, move cursor away, heading morphs into styled text
2. **Smart paste** — Paste URL over selection → creates `[selection](url)` link
3. **Drag & drop images** — Drop image → auto-saves to configurable path, inserts reference
4. **Live diagram** — Type mermaid code → diagram appears inline as you type (debounced)
5. **Click-to-toggle checkboxes** — Click `[ ]` → toggles to `[x]`
6. **Table Tab-navigation** — Tab between cells, auto-align columns
7. **Cmd+P quick switcher** — Fuzzy-find any file
8. **Cmd+Shift+P command palette** — Discover all commands
9. **Focus mode** — Dims everything except current paragraph
10. **Typewriter mode** — Current line stays centered vertically
11. **Outline sidebar** — Heading navigation (toggle with Cmd+Shift+O)
12. **Word count** — Subtle status bar (words, characters, reading time)

---

## Development Phases

### Phase 1: Foundation (MVP)
> Goal: Open .md files, edit with Fluid Mode, render basic markdown

- Swift/AppKit app shell with document-based architecture
- CodeMirror 6 integration in WKWebView
- Fluid Mode CM6 extension (basic: headings, bold, italic, links, images)
- pulldown-cmark integration via swift-bridge
- File open/save, recent files
- UTType registration for .md files
- Basic theme (light/dark following system)

### Phase 2: Diagrams
> Goal: First-class Mermaid + multi-language diagram support

- mmdr Rust integration for native Mermaid rendering
- Diagram Widget CM6 extension (render inline, click-to-edit)
- Content-hash diagram caching
- Kroki client for 28+ diagram languages
- KaTeX math rendering
- resvg for SVG→PNG export

### Phase 3: Polish
> Goal: The features that make users fanatical

- Fluid Mode advanced (tables, code blocks, footnotes, task lists)
- Focus mode + typewriter mode
- Smart paste, drag & drop images
- Table visual editor (Tab navigation)
- Command palette (Cmd+Shift+P)
- Outline sidebar
- Export (PDF, HTML, DOCX via comrak + templates)
- QuickLook extension
- Spotlight importer

### Phase 4: Power Features
> Goal: Compete with Obsidian's knowledge features

- Multi-file support (sidebar file browser)
- Full-text search across files
- `[[wikilinks]]` with backlinks
- Heading anchors and cross-file linking
- Custom CSS themes
- Vim keybindings (optional)
- Extension API (CM6 extension loading)

---

## Project Structure

```
macmd/
├── macmd-app/                  # Swift/AppKit application
│   ├── Sources/
│   │   ├── App/                # AppDelegate, main window
│   │   ├── Document/           # Document model, file handling
│   │   ├── Editor/             # WKWebView hosting, bridge to CM6
│   │   ├── Extensions/         # QuickLook, Spotlight, Finder
│   │   └── Preferences/        # Settings UI
│   ├── Resources/
│   │   ├── editor/             # CM6 bundle (HTML + JS + CSS)
│   │   └── Assets.xcassets
│   └── Info.plist
│
├── macmd-core/                 # Rust core library
│   ├── src/
│   │   ├── lib.rs              # Public API (swift-bridge exports)
│   │   ├── markdown/           # pulldown-cmark + comrak wrappers
│   │   ├── diagram/            # mmdr integration, Kroki client
│   │   ├── cache/              # Content-hash diagram cache
│   │   ├── export/             # PDF/HTML/DOCX export
│   │   └── search/             # Full-text search
│   ├── Cargo.toml
│   └── build.rs                # swift-bridge code generation
│
├── macmd-editor/               # CodeMirror 6 extensions (TypeScript)
│   ├── src/
│   │   ├── fluid-mode/         # Fluid Mode extension
│   │   │   ├── state.ts        # Block edit-state tracking
│   │   │   ├── decorations.ts  # Render/hide markdown syntax
│   │   │   ├── widgets.ts      # Complex element widgets
│   │   │   └── transitions.ts  # Animated morphing CSS
│   │   ├── diagram-widget/     # Diagram rendering extension
│   │   │   ├── renderer.ts     # Bridge to Rust renderer
│   │   │   ├── editor.ts       # Click-to-edit source view
│   │   │   └── cache.ts        # Content-hash lookup
│   │   ├── math-widget/        # KaTeX integration
│   │   ├── table-editor/       # Visual table editing
│   │   ├── smart-paste/        # URL → link, image handling
│   │   ├── focus-mode/         # Dim non-active paragraphs
│   │   ├── typewriter-mode/    # Center active line
│   │   └── bridge.ts           # WKWebView ↔ Swift messaging
│   ├── package.json
│   ├── tsconfig.json
│   └── rollup.config.js        # Bundle for WKWebView
│
├── macmd-tests/                # Test suites
│   ├── features/               # BDD feature files (Gherkin)
│   ├── swift-tests/            # XCTest (UI + integration)
│   ├── rust-tests/             # Rust unit + integration tests
│   └── ts-tests/               # Vitest for CM6 extensions
│
├── PROJECT.md                  # This file
└── CLAUDE.md                   # Dev instructions
```

---

## Tech Stack Summary

| Layer | Technology | Version | License |
|-------|-----------|---------|---------|
| App shell | Swift 6 + AppKit | Latest | — |
| Editor surface | CodeMirror 6 | Latest | MIT |
| Editor hosting | WKWebView | macOS 14+ | — |
| FFI bridge | swift-bridge | Latest | MIT/Apache |
| Markdown (edit) | pulldown-cmark | 0.12+ | MIT |
| Markdown (export) | comrak | 0.28+ | BSD-2 |
| Mermaid | mmdr | Latest | MIT |
| SVG rendering | resvg | 0.47+ | MPL-2.0 |
| Math | KaTeX | 0.16+ | MIT |
| Diagrams (multi) | Kroki API | — | MIT |
| Syntax highlight | tree-sitter | Latest | MIT |
| Text buffer | ropey | 1.6+ | MIT |
| JS bundling | Rollup | Latest | MIT |
| Testing (BDD) | Cucumber.js + XCUITest | — | MIT |
| Testing (Rust) | cargo test + proptest | — | MIT/Apache |
| Testing (TS) | Vitest | Latest | MIT |

## Minimum macOS Version

**macOS 14 (Sonoma)** — Required for:
- Latest WKWebView capabilities
- SwiftUI 5 for preferences
- Latest AppKit APIs

---

## Anti-Patterns We Deliberately Avoid

Based on research across 9 SOTA editors and 3 academic studies:

1. **No Electron** — Native Swift shell. 20MB vs 250MB. 500ms vs 5s startup.
2. **No split panes** — One editor surface. Fluid Mode eliminates the need.
3. **No configuration required** — Opinionated defaults for typography, spacing, theme.
4. **No plugin dependency** — Core features built-in. Extensions are optional power features.
5. **No proprietary format** — Pure .md files. Always. No database, no lock-in.
6. **No TextKit 2** — Even Apple's TextEdit has bugs with it. CodeMirror 6 is better.
7. **No feature creep** — A markdown editor, not an IDE. Not a note-taking database.

---

## Competitive Positioning

```
                    Native Performance
                          ▲
                          │
                  macmd ★ │
                          │         MarkEdit
                          │              •
        iA Writer •       │
                          │
  ──────────────────────────────────────────→ Feature Richness
                          │
            Bear •        │         Obsidian •
                          │
              Typora •    │
                          │
                          │         Zettlr •
                          │
```

macmd occupies the upper-right quadrant: **native performance AND rich features**.
No existing editor is in this space.
