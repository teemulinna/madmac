# macmd Testing Strategy — BDD & TDD

## Philosophy

**Outside-in development**: Start from user behavior (BDD features), derive unit tests (TDD),
implement to make them pass. Every feature starts as a Gherkin scenario before any code is written.

```
BDD Feature → Acceptance Criteria → TDD Unit Tests → Implementation → Green
```

---

## Three Test Layers

### Layer 1: BDD — Behavior (Gherkin + XCUITest)

User-visible behavior. Written BEFORE implementation.

```
macmd-tests/features/
├── opening-files.feature
├── fluid-mode-editing.feature
├── diagram-rendering.feature
├── math-rendering.feature
├── keyboard-shortcuts.feature
├── export.feature
├── finder-integration.feature
└── focus-typewriter.feature
```

**Example: Fluid Mode**

```gherkin
Feature: Fluid Mode inline editing
  As a user editing a markdown file
  I want to see rendered content that becomes editable on click
  So that I can focus on writing without split panes

  Scenario: Heading renders inline and becomes editable on click
    Given I open a file containing "# Hello World"
    Then I should see a styled heading "Hello World"
    And the markdown syntax "# " should be hidden

    When I click on the heading
    Then I should see the raw markdown "# Hello World"
    And the cursor should be positioned in the heading text

    When I press Escape
    Then the heading should animate back to rendered state
    And the markdown syntax should be hidden again

  Scenario: Bold text renders inline
    Given I open a file containing "This is **bold** text"
    Then I should see "bold" displayed in bold style
    And the "**" markers should be hidden

    When I click on the bold text
    Then I should see "**bold**" with visible markers
    And the text should remain bold-styled

  Scenario: Mermaid diagram renders inline
    Given I open a file containing a mermaid flowchart code block
    Then I should see a rendered SVG flowchart diagram
    And the code block syntax should be hidden

    When I click on the rendered diagram
    Then I should see the mermaid source code
    And a live preview of the diagram should appear below the source

    When I modify the mermaid source
    Then the live preview should update within 300ms

  Scenario: Multiple blocks can be edited simultaneously
    Given I open a file with a heading and a paragraph
    When I click on the heading to enter edit mode
    And I Cmd+click on the paragraph
    Then both blocks should be in edit mode
    And I should be able to type in either block
```

**Example: Diagram Rendering**

```gherkin
Feature: Diagram rendering
  As a user writing technical documentation
  I want diagrams to render from code blocks
  So that I can see visual output without leaving the editor

  Scenario Outline: Mermaid diagram types render correctly
    Given I open a file with a <type> mermaid diagram
    Then the diagram should render as an SVG
    And the SVG should be visually correct
    And rendering should complete in under <max_ms> milliseconds

    Examples:
      | type       | max_ms |
      | flowchart  | 10     |
      | sequence   | 10     |
      | class      | 10     |
      | state      | 10     |
      | er         | 10     |
      | gantt      | 10     |
      | pie        | 10     |
      | mindmap    | 10     |
      | timeline   | 10     |
      | sankey     | 15     |
      | xy-chart   | 15     |

  Scenario: Diagram caching prevents re-rendering
    Given I open a file with a mermaid diagram
    And the diagram has been rendered once
    When I scroll away and scroll back
    Then the diagram should appear from cache instantly
    And no re-rendering should occur

  Scenario: Kroki diagram rendering
    Given I open a file with a plantuml code block
    Then the diagram should render via Kroki API
    And a loading indicator should show during rendering

  Scenario: Syntax error in diagram shows graceful error
    Given I open a file with an invalid mermaid diagram
    Then I should see an error indicator on the code block
    And the last valid render should remain visible
    And the error message should be shown subtly
```

### Layer 2: TDD — Rust Core (cargo test + proptest)

Unit tests for the Rust core. Written BEFORE implementation using red-green-refactor.

```rust
// macmd-core/src/markdown/tests.rs

#[cfg(test)]
mod tests {
    use super::*;

    // --- Markdown Parsing ---

    #[test]
    fn parse_heading_returns_correct_level_and_text() {
        let result = parse_markdown("# Hello");
        assert_eq!(result.blocks[0], Block::Heading { level: 1, text: "Hello".into() });
    }

    #[test]
    fn parse_fenced_code_block_extracts_language() {
        let md = "```mermaid\ngraph TD\n  A-->B\n```";
        let result = parse_markdown(md);
        assert_eq!(result.blocks[0], Block::CodeBlock {
            language: Some("mermaid".into()),
            content: "graph TD\n  A-->B".into(),
        });
    }

    #[test]
    fn parse_gfm_table_with_alignment() {
        let md = "| Left | Center | Right |\n|:-----|:------:|------:|\n| a | b | c |";
        let result = parse_markdown(md);
        assert!(matches!(result.blocks[0], Block::Table { .. }));
    }

    // --- Diagram Rendering ---

    #[test]
    fn render_mermaid_flowchart_produces_valid_svg() {
        let svg = render_mermaid("graph TD\n  A-->B");
        assert!(svg.starts_with("<svg"));
        assert!(svg.contains("</svg>"));
    }

    #[test]
    fn render_mermaid_invalid_syntax_returns_error() {
        let result = try_render_mermaid("graph INVALID\n  ???");
        assert!(result.is_err());
    }

    #[test]
    fn render_mermaid_completes_under_10ms() {
        let start = std::time::Instant::now();
        render_mermaid("graph TD\n  A-->B\n  B-->C\n  C-->D");
        assert!(start.elapsed().as_millis() < 10);
    }

    // --- Diagram Caching ---

    #[test]
    fn cache_stores_and_retrieves_by_content_hash() {
        let cache = DiagramCache::new_temp();
        let svg = "<svg>test</svg>";
        let source = "graph TD\n  A-->B";

        cache.store(source, svg);
        assert_eq!(cache.get(source), Some(svg.to_string()));
    }

    #[test]
    fn cache_returns_none_for_modified_source() {
        let cache = DiagramCache::new_temp();
        cache.store("graph TD\n  A-->B", "<svg>1</svg>");
        assert_eq!(cache.get("graph TD\n  A-->C"), None);
    }

    // --- Export ---

    #[test]
    fn export_html_includes_rendered_diagrams() {
        let md = "# Title\n\n```mermaid\ngraph TD\n  A-->B\n```";
        let html = export_to_html(md);
        assert!(html.contains("<h1>Title</h1>"));
        assert!(html.contains("<svg"));
    }

    // --- Property-based tests ---

    use proptest::prelude::*;

    proptest! {
        #[test]
        fn roundtrip_markdown_parse_render(s in "[a-zA-Z0-9 #*_\\[\\]()\\n]{1,500}") {
            // Parsing should never panic on arbitrary input
            let _ = parse_markdown(&s);
        }

        #[test]
        fn diagram_cache_is_deterministic(source in "[a-z \\-\\>]{1,200}") {
            let cache = DiagramCache::new_temp();
            let svg = format!("<svg>{}</svg>", &source);
            cache.store(&source, &svg);
            assert_eq!(cache.get(&source), Some(svg));
        }
    }
}
```

### Layer 3: TDD — TypeScript / CM6 Extensions (Vitest)

Unit tests for CodeMirror 6 extensions.

```typescript
// macmd-editor/src/fluid-mode/__tests__/fluid-mode.test.ts

import { describe, it, expect } from 'vitest'
import { EditorState } from '@codemirror/state'
import { EditorView } from '@codemirror/view'
import { fluidMode } from '../state'
import { getEditingBlocks, isBlockEditing } from '../state'

describe('Fluid Mode State', () => {
  it('starts with no blocks in editing state', () => {
    const state = EditorState.create({
      doc: '# Hello\n\nParagraph',
      extensions: [fluidMode()],
    })
    expect(getEditingBlocks(state)).toEqual([])
  })

  it('marks block as editing when cursor enters', () => {
    const state = createStateWithCursorAt('# Hello\n\nParagraph', 3)
    expect(isBlockEditing(state, 0)).toBe(true)  // heading block
    expect(isBlockEditing(state, 1)).toBe(false)  // paragraph block
  })

  it('supports multiple blocks in editing state', () => {
    const state = createStateWithMultiCursor(
      '# Hello\n\nParagraph',
      [3, 12]  // cursor in heading and paragraph
    )
    expect(getEditingBlocks(state)).toHaveLength(2)
  })
})

describe('Fluid Mode Decorations', () => {
  it('hides heading markers in rendered blocks', () => {
    const view = createView('# Hello\n\n## World')
    // Cursor not in any block
    const decos = getDecorations(view)
    expect(decos).toContainReplace({ from: 0, to: 2 })  // "# " hidden
    expect(decos).toContainReplace({ from: 10, to: 13 }) // "## " hidden
  })

  it('shows heading markers when cursor enters block', () => {
    const view = createViewWithCursorAt('# Hello', 3)
    const decos = getDecorations(view)
    expect(decos).not.toContainReplace({ from: 0, to: 2 }) // "# " visible
  })

  it('hides bold markers in rendered blocks', () => {
    const view = createView('This is **bold** text')
    const decos = getDecorations(view)
    expect(decos).toContainReplace({ from: 8, to: 10 })   // "**" hidden
    expect(decos).toContainReplace({ from: 14, to: 16 })  // "**" hidden
  })
})

describe('Diagram Widget', () => {
  it('renders mermaid code block as widget', () => {
    const view = createView('```mermaid\ngraph TD\n  A-->B\n```')
    const widgets = getWidgets(view)
    expect(widgets).toHaveLength(1)
    expect(widgets[0].type).toBe('diagram')
  })

  it('shows source editor on widget click', async () => {
    const view = createView('```mermaid\ngraph TD\n  A-->B\n```')
    await clickWidget(view, 0)
    expect(isBlockEditing(view.state, 0)).toBe(true)
  })
})

describe('Smart Paste', () => {
  it('wraps selected text in link when pasting URL', () => {
    const view = createViewWithSelection('Hello World', 0, 5)
    simulatePaste(view, 'https://example.com')
    expect(view.state.doc.toString()).toBe('[Hello](https://example.com) World')
  })

  it('pastes URL normally when nothing selected', () => {
    const view = createViewWithCursorAt('Hello', 5)
    simulatePaste(view, 'https://example.com')
    expect(view.state.doc.toString()).toBe('Hellohttps://example.com')
  })
})
```

---

## Test Execution

### Development Loop (per feature)

```
1. Write Gherkin scenario           → features/*.feature
2. Run BDD → RED (not implemented)  → npm run test:bdd
3. Write Rust unit tests            → cargo test (RED)
4. Implement Rust code              → cargo test (GREEN)
5. Write CM6 unit tests             → npx vitest (RED)
6. Implement CM6 extension          → npx vitest (GREEN)
7. Wire Swift ↔ Rust ↔ CM6          → xcodebuild test
8. Run BDD → GREEN                  → npm run test:bdd
9. Refactor                         → All tests GREEN
```

### Commands

```bash
# All tests
make test

# Individual layers
cargo test                          # Rust core
npx vitest                          # CM6 extensions
xcodebuild test -scheme macmd       # Swift UI + integration
npm run test:bdd                    # BDD acceptance

# Watch mode (TDD)
cargo watch -x test                 # Rust
npx vitest --watch                  # TypeScript

# Performance benchmarks
cargo bench                         # Rust benchmarks (criterion)

# Property-based testing
cargo test --features proptest      # Rust proptest
```

### CI Pipeline

```yaml
# .github/workflows/test.yml
test:
  - rust-tests:    cargo test --all-features
  - rust-bench:    cargo bench --no-run  # compile check only
  - ts-tests:      npx vitest run
  - swift-tests:   xcodebuild test -scheme macmd
  - bdd-tests:     npm run test:bdd
  - lint:          cargo clippy && npx eslint && swiftlint
```

---

## Coverage Targets

| Layer | Target | Rationale |
|-------|--------|-----------|
| Rust core (markdown parsing) | 95% | Critical path, many edge cases |
| Rust core (diagram rendering) | 90% | Integration-heavy, visual output |
| Rust core (caching) | 100% | Data integrity critical |
| CM6 extensions (Fluid Mode) | 85% | UI logic, some visual-only code |
| CM6 extensions (widgets) | 80% | Hard to test visual rendering |
| Swift (document model) | 90% | File handling must be reliable |
| Swift (UI) | 70% | XCUITest for critical flows |
| BDD scenarios | 100% of user stories | Every feature has acceptance tests |
