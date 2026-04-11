import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import {
  createEditor,
  getContent,
  setContent,
  setMode,
  setTheme,
  getMode,
  getTheme,
  getView,
  setFontSize,
  getFontSize,
  showLineNumbers,
  setZoom,
  getZoom,
  resetZoom,
  KROKI_LANGUAGES,
  renderKrokiDiagram,
} from "./editor";
import type { EditorMode } from "./editor";
import type { ThemeVariant } from "./theme";
import { EditorView } from "@codemirror/view";
import { EditorState } from "@codemirror/state";

// ---- TDD: Red-Green-Refactor ----
// These tests are written BEFORE implementation changes.
// Run: npx vitest

describe("Editor creation", () => {
  let parent: HTMLElement;
  let view: EditorView;

  beforeEach(() => {
    parent = document.createElement("div");
    document.body.appendChild(parent);
  });

  afterEach(() => {
    view?.destroy();
    parent.remove();
  });

  it("creates an editor in the parent element", () => {
    view = createEditor(parent, "# Hello");
    expect(parent.querySelector(".cm-editor")).toBeTruthy();
  });

  it("initializes with provided content", () => {
    view = createEditor(parent, "# Test Content");
    expect(getContent()).toBe("# Test Content");
  });

  it("initializes empty when no content provided", () => {
    view = createEditor(parent, "");
    expect(getContent()).toBe("");
  });

  it("defaults to reading mode", () => {
    view = createEditor(parent, "# Hello");
    // In reading mode, the editor should not be editable
    const editable = view.state.facet(EditorView.editable);
    expect(editable).toBe(false);
  });

  it("is editable in fluid mode", () => {
    view = createEditor(parent, "# Hello", "fluid");
    const editable = view.state.facet(EditorView.editable);
    expect(editable).toBe(true);
  });
});

describe("Content management", () => {
  let parent: HTMLElement;
  let view: EditorView;

  beforeEach(() => {
    parent = document.createElement("div");
    document.body.appendChild(parent);
    view = createEditor(parent, "Initial content", "fluid");
  });

  afterEach(() => {
    view?.destroy();
    parent.remove();
  });

  it("setContent replaces all content", () => {
    setContent("New content");
    expect(getContent()).toBe("New content");
  });

  it("setContent with empty string clears the editor", () => {
    setContent("");
    expect(getContent()).toBe("");
  });

  it("setContent preserves markdown syntax", () => {
    const md = "# Heading\n\n**bold** and *italic*\n\n```js\ncode\n```";
    setContent(md);
    expect(getContent()).toBe(md);
  });

  it("handles unicode content correctly", () => {
    const md = "# Hyvaa paivaa\n\nkonnichiwa";
    setContent(md);
    expect(getContent()).toBe(md);
  });

  it("handles large content", () => {
    const lines = Array.from({ length: 10000 }, (_, i) => `Line ${i + 1}`);
    const content = lines.join("\n");
    setContent(content);
    expect(getContent()).toBe(content);
  });
});

describe("Reading Mode rendering", () => {
  let parent: HTMLElement;
  let view: EditorView;

  beforeEach(() => {
    parent = document.createElement("div");
    document.body.appendChild(parent);
  });

  afterEach(() => {
    view?.destroy();
    parent.remove();
  });

  it("renders markdown with syntax highlighting", () => {
    view = createEditor(parent, "# Hello\n\n**bold**", "reading");
    // CM6 with markdown language should add syntax tokens
    const cmContent = parent.querySelector(".cm-content");
    expect(cmContent).toBeTruthy();
  });

  it("is not editable in reading mode", () => {
    view = createEditor(parent, "# Hello", "reading");
    const readOnly = view.state.facet(EditorView.editable);
    expect(readOnly).toBe(false);
  });

  it("has line wrapping enabled", () => {
    view = createEditor(parent, "A ".repeat(200), "reading");
    // Line wrapping is configured as an extension
    // The actual wrapping depends on container width
    expect(parent.querySelector(".cm-editor")).toBeTruthy();
  });
});

// ---- NEW TESTS: Theme switching ----

describe("Theme switching", () => {
  let parent: HTMLElement;
  let view: EditorView;

  beforeEach(() => {
    parent = document.createElement("div");
    document.body.appendChild(parent);
  });

  afterEach(() => {
    view?.destroy();
    parent.remove();
  });

  it("can create editor with explicit light theme", () => {
    view = createEditor(parent, "# Hello", "reading", "light");
    expect(getTheme()).toBe("light");
  });

  it("can create editor with explicit dark theme", () => {
    view = createEditor(parent, "# Hello", "reading", "dark");
    expect(getTheme()).toBe("dark");
  });

  it("setTheme switches to dark", () => {
    view = createEditor(parent, "# Hello", "reading", "light");
    setTheme("dark");
    expect(getTheme()).toBe("dark");
  });

  it("setTheme switches back to light", () => {
    view = createEditor(parent, "# Hello", "reading", "dark");
    setTheme("light");
    expect(getTheme()).toBe("light");
  });

  it("editor remains functional after theme switch", () => {
    view = createEditor(parent, "# Test", "fluid", "light");
    setTheme("dark");
    setContent("New content after theme switch");
    expect(getContent()).toBe("New content after theme switch");
  });
});

// ---- NEW TESTS: Mode switching with compartments ----

describe("Mode switching with compartments", () => {
  let parent: HTMLElement;
  let view: EditorView;

  beforeEach(() => {
    parent = document.createElement("div");
    document.body.appendChild(parent);
  });

  afterEach(() => {
    view?.destroy();
    parent.remove();
  });

  it("switches from reading to fluid mode", () => {
    view = createEditor(parent, "# Hello", "reading");
    expect(view.state.facet(EditorView.editable)).toBe(false);

    setMode("fluid");
    // After compartment reconfigure, the same view instance should now be editable
    const v = getView();
    expect(v).toBe(view); // same instance — not recreated
    expect(v!.state.facet(EditorView.editable)).toBe(true);
  });

  it("switches from fluid to reading mode", () => {
    view = createEditor(parent, "# Hello", "fluid");
    expect(view.state.facet(EditorView.editable)).toBe(true);

    setMode("reading");
    const v = getView();
    expect(v!.state.facet(EditorView.editable)).toBe(false);
  });

  it("preserves content across mode switches", () => {
    view = createEditor(parent, "# Persistent", "reading");
    setMode("fluid");
    expect(getContent()).toBe("# Persistent");
    setMode("reading");
    expect(getContent()).toBe("# Persistent");
  });

  it("no-ops when setting the same mode", () => {
    view = createEditor(parent, "# Hello", "reading");
    setMode("reading");
    expect(getMode()).toBe("reading");
    expect(view.state.facet(EditorView.editable)).toBe(false);
  });

  it("reports current mode via getMode", () => {
    view = createEditor(parent, "", "reading");
    expect(getMode()).toBe("reading");
    setMode("fluid");
    expect(getMode()).toBe("fluid");
  });

  it("reading mode is read-only at the state level", () => {
    view = createEditor(parent, "test", "reading");
    const readOnly = view.state.facet(EditorState.readOnly);
    expect(readOnly).toBe(true);
  });

  it("fluid mode is not read-only at the state level", () => {
    view = createEditor(parent, "test", "fluid");
    const readOnly = view.state.facet(EditorState.readOnly);
    expect(readOnly).toBe(false);
  });
});

// ---- NEW TESTS: Bridge message posting ----

describe("Bridge message posting", () => {
  let parent: HTMLElement;
  let view: EditorView;
  let postMessageSpy: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    parent = document.createElement("div");
    document.body.appendChild(parent);

    // Mock the WKWebView message handler
    postMessageSpy = vi.fn();
    (window as Record<string, unknown>).webkit = {
      messageHandlers: {
        MadMac: { postMessage: postMessageSpy },
      },
    };
  });

  afterEach(() => {
    view?.destroy();
    parent.remove();
    delete (window as Record<string, unknown>).webkit;
  });

  it("sends editorReady on creation", () => {
    view = createEditor(parent, "# Hello", "reading", "light");
    expect(postMessageSpy).toHaveBeenCalledWith(
      expect.objectContaining({ action: "ready" }),
    );
  });

  it("sends contentChanged when content is modified", () => {
    view = createEditor(parent, "initial", "fluid", "light");
    postMessageSpy.mockClear();

    setContent("updated");
    expect(postMessageSpy).toHaveBeenCalledWith(
      expect.objectContaining({ action: "contentChanged" }),
    );
  });

  it("sends modeChanged when mode switches", () => {
    view = createEditor(parent, "# Hello", "reading", "light");
    postMessageSpy.mockClear();

    setMode("fluid");
    expect(postMessageSpy).toHaveBeenCalledWith(
      expect.objectContaining({ action: "modeChanged", mode: "fluid" }),
    );
  });

  it("sends themeChanged when theme switches", () => {
    view = createEditor(parent, "# Hello", "reading", "light");
    postMessageSpy.mockClear();

    setTheme("dark");
    expect(postMessageSpy).toHaveBeenCalledWith(
      expect.objectContaining({ action: "themeChanged", theme: "dark" }),
    );
  });

  it("does not throw when webkit is not available", () => {
    delete (window as Record<string, unknown>).webkit;
    expect(() => {
      view = createEditor(parent, "# Hello", "reading", "light");
    }).not.toThrow();
  });
});

// ---- NEW TESTS: Markdown syntax styling ----

describe("Markdown syntax styling", () => {
  let parent: HTMLElement;
  let view: EditorView;

  beforeEach(() => {
    parent = document.createElement("div");
    document.body.appendChild(parent);
  });

  afterEach(() => {
    view?.destroy();
    parent.remove();
  });

  it("creates editor with markdown language support", () => {
    view = createEditor(parent, "# Heading\n\n**bold**", "reading", "light");
    // The editor should have the cm-content element
    expect(parent.querySelector(".cm-content")).toBeTruthy();
    // And the content should be intact
    expect(getContent()).toBe("# Heading\n\n**bold**");
  });

  it("heading line classes plugin is active", () => {
    // The headingLineClasses ViewPlugin is included as an extension
    // We verify the editor was created successfully with it
    view = createEditor(
      parent,
      "# Heading 1\n## Heading 2\n### Heading 3",
      "reading",
      "light",
    );
    expect(parent.querySelector(".cm-editor")).toBeTruthy();
    expect(getContent()).toBe("# Heading 1\n## Heading 2\n### Heading 3");
  });

  it("works with code blocks in content", () => {
    const md = "# Title\n\n```python\ndef hello():\n    print('hi')\n```\n\nDone.";
    view = createEditor(parent, md, "reading", "light");
    expect(getContent()).toBe(md);
  });

  it("works with blockquotes in content", () => {
    const md = "> This is a quote\n> spanning two lines";
    view = createEditor(parent, md, "reading", "light");
    expect(getContent()).toBe(md);
  });

  it("syntax highlighting switches with theme", () => {
    view = createEditor(parent, "# Hello **world**", "reading", "light");
    setTheme("dark");
    expect(getContent()).toBe("# Hello **world**");
    expect(getTheme()).toBe("dark");
  });
});

// ---- NEW TESTS: Sepia theme ----

describe("Sepia theme", () => {
  let parent: HTMLElement;
  let view: EditorView;

  beforeEach(() => {
    parent = document.createElement("div");
    document.body.appendChild(parent);
  });

  afterEach(() => {
    view?.destroy();
    parent.remove();
  });

  it("accepts sepia as theme variant", () => {
    view = createEditor(parent, "# Hello", "reading", "sepia");
    expect(getTheme()).toBe("sepia");
  });

  it("switches to sepia at runtime", () => {
    view = createEditor(parent, "# Hello", "reading", "light");
    setTheme("sepia");
    expect(getTheme()).toBe("sepia");
  });

  it("cycles through all three themes", () => {
    view = createEditor(parent, "test", "fluid", "light");
    setTheme("dark");
    expect(getTheme()).toBe("dark");
    setTheme("sepia");
    expect(getTheme()).toBe("sepia");
    setTheme("light");
    expect(getTheme()).toBe("light");
  });

  it("content preserved after theme change to sepia", () => {
    view = createEditor(parent, "# Preserved", "fluid", "light");
    setTheme("sepia");
    expect(getContent()).toBe("# Preserved");
  });
});

// ---- NEW TESTS: Font size ----

describe("Font size", () => {
  let parent: HTMLElement;
  let view: EditorView;

  beforeEach(() => {
    parent = document.createElement("div");
    document.body.appendChild(parent);
  });

  afterEach(() => {
    view?.destroy();
    parent.remove();
  });

  it("setFontSize updates font size", () => {
    view = createEditor(parent, "test", "fluid");
    setFontSize(18);
    expect(getFontSize()).toBe(18);
  });

  it("getFontSize returns default 14", () => {
    view = createEditor(parent, "test", "fluid");
    expect(getFontSize()).toBe(14);
  });

  it("clamps minimum to 10", () => {
    view = createEditor(parent, "test", "fluid");
    setFontSize(5);
    expect(getFontSize()).toBeGreaterThanOrEqual(10);
  });

  it("clamps maximum to 32", () => {
    view = createEditor(parent, "test", "fluid");
    setFontSize(50);
    expect(getFontSize()).toBeLessThanOrEqual(32);
  });

  it("content preserved after font size change", () => {
    view = createEditor(parent, "# Keep this", "fluid");
    setFontSize(20);
    expect(getContent()).toBe("# Keep this");
  });
});

// ---- NEW TESTS: Unified zoom (text + diagrams + math) ----

describe("Unified zoom", () => {
  let parent: HTMLElement;
  let view: EditorView;

  beforeEach(() => {
    parent = document.createElement("div");
    document.body.appendChild(parent);
    // Reset zoom before each test (module state)
    resetZoom();
    document.documentElement.style.removeProperty("--md-zoom");
  });

  afterEach(() => {
    view?.destroy();
    parent.remove();
    document.documentElement.style.removeProperty("--md-zoom");
  });

  it("setZoom sets --md-zoom CSS custom property on document root", () => {
    view = createEditor(parent, "test", "reading");
    setZoom(1.5);
    const zoomValue = document.documentElement.style.getPropertyValue("--md-zoom");
    expect(zoomValue).toBe("1.5");
  });

  it("getZoom returns the current zoom level", () => {
    view = createEditor(parent, "test", "reading");
    setZoom(2.0);
    expect(getZoom()).toBe(2.0);
  });

  it("getZoom returns 1.0 by default", () => {
    view = createEditor(parent, "test", "reading");
    expect(getZoom()).toBe(1.0);
  });

  it("resetZoom returns to 1.0", () => {
    view = createEditor(parent, "test", "reading");
    setZoom(2.5);
    resetZoom();
    expect(getZoom()).toBe(1.0);
    expect(document.documentElement.style.getPropertyValue("--md-zoom")).toBe("1");
  });

  it("clamps minimum to 0.5", () => {
    view = createEditor(parent, "test", "reading");
    setZoom(0.1);
    expect(getZoom()).toBeGreaterThanOrEqual(0.5);
  });

  it("clamps maximum to 3.0", () => {
    view = createEditor(parent, "test", "reading");
    setZoom(5.0);
    expect(getZoom()).toBeLessThanOrEqual(3.0);
  });

  it("zoom does not affect content", () => {
    view = createEditor(parent, "# Original content", "reading");
    setZoom(1.5);
    expect(getContent()).toBe("# Original content");
  });

  it("zoom level 1.0 means 100%", () => {
    view = createEditor(parent, "test", "reading");
    setZoom(1.0);
    expect(getZoom()).toBe(1.0);
  });

  it("multiple zoom changes track correctly", () => {
    view = createEditor(parent, "test", "reading");
    setZoom(1.2);
    setZoom(1.4);
    setZoom(2.0);
    expect(getZoom()).toBe(2.0);
    expect(document.documentElement.style.getPropertyValue("--md-zoom")).toBe("2");
  });
});

// ---- NEW TESTS: Kroki diagram rendering ----

describe("Kroki diagram rendering", () => {
  let parent: HTMLElement;
  let view: EditorView;
  const originalFetch = globalThis.fetch;

  beforeEach(() => {
    parent = document.createElement("div");
    document.body.appendChild(parent);
  });

  afterEach(() => {
    view?.destroy();
    parent.remove();
    globalThis.fetch = originalFetch;
  });

  it("KROKI_LANGUAGES contains plantuml, graphviz, d2", () => {
    expect(KROKI_LANGUAGES).toContain("plantuml");
    expect(KROKI_LANGUAGES).toContain("graphviz");
    expect(KROKI_LANGUAGES).toContain("d2");
  });

  it("KROKI_LANGUAGES does not contain mermaid (handled separately)", () => {
    expect(KROKI_LANGUAGES).not.toContain("mermaid");
  });

  it("KROKI_LANGUAGES does not contain general languages like python", () => {
    expect(KROKI_LANGUAGES).not.toContain("python");
    expect(KROKI_LANGUAGES).not.toContain("javascript");
  });

  it("renderKrokiDiagram returns SVG on success", async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: true,
      text: () => Promise.resolve('<svg viewBox="0 0 100 100"><text>Test</text></svg>'),
    });

    const svg = await renderKrokiDiagram("plantuml", "@startuml\nA -> B\n@enduml");
    expect(svg).toContain("<svg");
    expect(svg).toContain("Test");
  });

  it("renderKrokiDiagram returns null on fetch error", async () => {
    globalThis.fetch = vi.fn().mockRejectedValue(new Error("network down"));

    const svg = await renderKrokiDiagram("plantuml", "@startuml\nA -> B\n@enduml");
    expect(svg).toBeNull();
  });

  it("renderKrokiDiagram returns null on non-ok response", async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 400,
      text: () => Promise.resolve("Bad request"),
    });

    const svg = await renderKrokiDiagram("plantuml", "invalid source");
    expect(svg).toBeNull();
  });

  it("renderKrokiDiagram calls correct Kroki URL", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      text: () => Promise.resolve("<svg></svg>"),
    });
    globalThis.fetch = fetchMock;

    await renderKrokiDiagram("graphviz", "digraph { A -> B }");
    expect(fetchMock).toHaveBeenCalledWith(
      "https://kroki.io/graphviz/svg",
      expect.objectContaining({
        method: "POST",
        body: "digraph { A -> B }",
      }),
    );
  });
});

// ---- NEW TESTS: Line numbers ----

describe("Line numbers", () => {
  let parent: HTMLElement;
  let view: EditorView;

  beforeEach(() => {
    parent = document.createElement("div");
    document.body.appendChild(parent);
  });

  afterEach(() => {
    view?.destroy();
    parent.remove();
  });

  it("showLineNumbers(true) enables line number gutter", () => {
    view = createEditor(parent, "Line 1\nLine 2", "fluid");
    showLineNumbers(true);
    // The gutter should exist in the DOM
    const gutters = parent.querySelector(".cm-gutters");
    expect(gutters).toBeTruthy();
  });

  it("showLineNumbers(false) hides gutters", () => {
    view = createEditor(parent, "test", "fluid");
    showLineNumbers(true);
    showLineNumbers(false);
    // Gutters should be hidden
    const gutters = parent.querySelector(".cm-lineNumbers");
    expect(gutters).toBeFalsy();
  });
});
