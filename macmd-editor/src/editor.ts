import { EditorState, Compartment, Extension } from "@codemirror/state";
import { EditorView, keymap } from "@codemirror/view";
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands";
import { markdown, markdownLanguage } from "@codemirror/lang-markdown";
import { languages } from "@codemirror/language-data";
import { syntaxHighlighting } from "@codemirror/language";
import { search, searchKeymap } from "@codemirror/search";
import {
  themeCompartment,
  getThemeExtension,
  themeExtensions,
  detectSystemTheme,
  type ThemeVariant,
} from "./theme";
import {
  lightMarkdownStyle,
  darkMarkdownStyle,
  headingLineClasses,
} from "./markdown-styles";
import {
  contentChangeNotifier,
  notifyReady,
  notifyModeChanged,
  notifyThemeChanged,
} from "./bridge";
import { fluidMode } from "./fluid-mode";
import { mermaidExtension } from "./diagram-widget";
import { mathExtension } from "./math-widget";

export type EditorMode = "reading" | "fluid";

/**
 * Compartments for dynamic reconfiguration without recreating the editor.
 */
const editableCompartment = new Compartment();
const readOnlyCompartment = new Compartment();
const highlightCompartment = new Compartment();
const fluidModeCompartment = new Compartment();

let view: EditorView | null = null;
let currentMode: EditorMode = "reading";
let currentTheme: ThemeVariant = "light";

/**
 * Build the extensions for a given editing mode.
 */
function modeExtensions(mode: EditorMode): {
  editable: Extension;
  readOnly: Extension;
} {
  return {
    editable: EditorView.editable.of(mode === "fluid"),
    readOnly: EditorState.readOnly.of(mode === "reading"),
  };
}

/**
 * Build the highlight style extension for the given theme variant.
 */
function highlightExtension(variant: ThemeVariant): Extension {
  return syntaxHighlighting(
    variant === "dark" ? darkMarkdownStyle : lightMarkdownStyle,
  );
}

/**
 * Create a new CodeMirror 6 editor inside the given parent element.
 */
export function createEditor(
  parent: HTMLElement,
  content: string = "",
  mode: EditorMode = "reading",
  theme?: ThemeVariant,
): EditorView {
  currentMode = mode;
  currentTheme = theme ?? detectSystemTheme();

  const modeExts = modeExtensions(mode);

  const state = EditorState.create({
    doc: content,
    extensions: [
      history(),
      keymap.of([...defaultKeymap, ...historyKeymap, ...searchKeymap]),
      markdown({ base: markdownLanguage, codeLanguages: languages }),
      highlightCompartment.of(highlightExtension(currentTheme)),
      themeExtensions(currentTheme),
      headingLineClasses,
      search(),
      EditorView.lineWrapping,
      editableCompartment.of(modeExts.editable),
      readOnlyCompartment.of(modeExts.readOnly),
      fluidModeCompartment.of(mode === "fluid" ? fluidMode() : []),
      mermaidExtension(),
      mathExtension(),
      contentChangeNotifier(),
    ],
  });

  view = new EditorView({ state, parent });
  notifyReady();
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
 * Switch between Reading Mode and Fluid Mode using compartment reconfiguration.
 * Does NOT recreate the editor — just reconfigures the relevant compartments.
 */
export function setMode(mode: EditorMode): void {
  if (!view || mode === currentMode) return;
  currentMode = mode;

  const modeExts = modeExtensions(mode);
  view.dispatch({
    effects: [
      editableCompartment.reconfigure(modeExts.editable),
      readOnlyCompartment.reconfigure(modeExts.readOnly),
      fluidModeCompartment.reconfigure(mode === "fluid" ? fluidMode() : []),
    ],
  });

  notifyModeChanged(mode);
}

/**
 * Switch between light and dark theme using compartment reconfiguration.
 */
export function setTheme(theme: ThemeVariant): void {
  if (!view) return;
  currentTheme = theme;

  view.dispatch({
    effects: [
      themeCompartment.reconfigure(getThemeExtension(theme)),
      highlightCompartment.reconfigure(highlightExtension(theme)),
    ],
  });

  notifyThemeChanged(theme);
}

/**
 * Get the current editor mode.
 */
export function getMode(): EditorMode {
  return currentMode;
}

/**
 * Get the current theme variant.
 */
export function getTheme(): ThemeVariant {
  return currentTheme;
}

/**
 * Get the raw EditorView instance (for advanced use / testing).
 */
export function getView(): EditorView | null {
  return view;
}
