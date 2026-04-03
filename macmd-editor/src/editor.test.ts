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
        macmd: { postMessage: postMessageSpy },
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
      expect.objectContaining({ type: "editorReady" }),
    );
  });

  it("sends contentChanged when content is modified", () => {
    view = createEditor(parent, "initial", "fluid", "light");
    postMessageSpy.mockClear();

    setContent("updated");
    expect(postMessageSpy).toHaveBeenCalledWith(
      expect.objectContaining({ type: "contentChanged" }),
    );
  });

  it("sends modeChanged when mode switches", () => {
    view = createEditor(parent, "# Hello", "reading", "light");
    postMessageSpy.mockClear();

    setMode("fluid");
    expect(postMessageSpy).toHaveBeenCalledWith(
      expect.objectContaining({ type: "modeChanged", mode: "fluid" }),
    );
  });

  it("sends themeChanged when theme switches", () => {
    view = createEditor(parent, "# Hello", "reading", "light");
    postMessageSpy.mockClear();

    setTheme("dark");
    expect(postMessageSpy).toHaveBeenCalledWith(
      expect.objectContaining({ type: "themeChanged", theme: "dark" }),
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
    // Editor should still be functional after syntax highlight reconfiguration
    expect(getContent()).toBe("# Hello **world**");
    expect(getTheme()).toBe("dark");
  });
});
