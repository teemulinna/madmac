import { EditorState } from "@codemirror/state";
import { EditorView, keymap } from "@codemirror/view";
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands";
import { markdown, markdownLanguage } from "@codemirror/lang-markdown";
import { languages } from "@codemirror/language-data";
import { syntaxHighlighting, defaultHighlightStyle } from "@codemirror/language";
import { search, searchKeymap } from "@codemirror/search";

export type EditorMode = "reading" | "fluid";

let view: EditorView | null = null;
let currentMode: EditorMode = "reading";

/**
 * Create a new CodeMirror 6 editor inside the given parent element.
 */
export function createEditor(
  parent: HTMLElement,
  content: string = "",
  mode: EditorMode = "reading",
): EditorView {
  currentMode = mode;

  const state = EditorState.create({
    doc: content,
    extensions: [
      history(),
      keymap.of([...defaultKeymap, ...historyKeymap, ...searchKeymap]),
      markdown({ base: markdownLanguage, codeLanguages: languages }),
      syntaxHighlighting(defaultHighlightStyle),
      search(),
      EditorView.lineWrapping,
      EditorView.editable.of(mode === "fluid"),
      EditorState.readOnly.of(mode === "reading"),
    ],
  });

  view = new EditorView({ state, parent });
  return view;
}

/**
 * Set the editor content (replaces all).
 */
export function setContent(content: string): void {
  if (!view) return;
  view.dispatch({
    changes: { from: 0, to: view.state.doc.length, insert: content },
  });
}

/**
 * Get the current editor content as raw markdown string.
 */
export function getContent(): string {
  if (!view) return "";
  return view.state.doc.toString();
}

/**
 * Switch between Reading Mode and Fluid Mode.
 */
export function setMode(mode: EditorMode): void {
  if (!view || mode === currentMode) return;
  currentMode = mode;

  // Reconfigure the editor with new extensions
  view.dispatch({
    effects: [
      // TODO: Implement mode switching via CM6 compartments
      // For now, recreate the editor (Phase 1a basic version)
    ],
  });
}
