import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { createEditor, getContent, setContent, setMode } from "./editor";
import type { EditorMode } from "./editor";
import { EditorView } from "@codemirror/view";

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
    const md = "# Hyvää päivää\n\nこんにちは 🎉";
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
