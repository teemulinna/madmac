import { EditorView } from "@codemirror/view";
import { Extension } from "@codemirror/state";
import { Compartment } from "@codemirror/state";

export type ThemeVariant = "light" | "dark" | "sepia";

export const themeCompartment = new Compartment();
export const fontSizeCompartment = new Compartment();
export const gutterCompartment = new Compartment();

const baseTheme = EditorView.baseTheme({
  "&": {
    fontFamily: "'SF Mono', ui-monospace, Menlo, Monaco, Consolas, 'Courier New', monospace",
    fontSize: "14px",
    lineHeight: "1.5",
    fontKerning: "none",
  },
  ".cm-content": {
    padding: "16px 0",
    caretColor: "transparent",
  },
  ".cm-scroller": {
    overflow: "auto",
  },
  ".cm-focused .cm-cursor": {
    borderLeftWidth: "2px",
    borderRadius: "1px",
  },
  ".cm-code-block": {
    padding: "1px 0",
  },
});

// --- Light ---
const lightTheme = EditorView.theme(
  {
    "&": { backgroundColor: "#ffffff", color: "#24292f" },
    ".cm-cursor": { borderLeftColor: "#0a69da" },
    ".cm-selectionBackground, ::selection": { backgroundColor: "#add6ff" },
    ".cm-activeLine": { backgroundColor: "#eaeef27f" },
    ".cm-line": { padding: "0" },
    ".cm-heading-1, .cm-heading-2, .cm-heading-3, .cm-heading-4, .cm-heading-5, .cm-heading-6": { color: "#0550ae" },
    ".cm-code-block": { backgroundColor: "#f6f8fa", borderRadius: "4px" },
    ".cm-blockquote": { color: "#116329" },
    ".cm-gutters": { backgroundColor: "#ffffff", color: "#8c959f", borderRight: "none" },
  },
  { dark: false },
);

// --- Dark ---
const darkTheme = EditorView.theme(
  {
    "&": { backgroundColor: "#0d1116", color: "#c9d1d9" },
    ".cm-cursor": { borderLeftColor: "#58a6ff" },
    ".cm-selectionBackground, ::selection": { backgroundColor: "#264f78" },
    ".cm-activeLine": { backgroundColor: "#6e76811a" },
    ".cm-line": { padding: "0" },
    ".cm-heading-1, .cm-heading-2, .cm-heading-3, .cm-heading-4, .cm-heading-5, .cm-heading-6": { color: "#79c0ff" },
    ".cm-code-block": { backgroundColor: "#161b22", borderRadius: "4px" },
    ".cm-blockquote": { color: "#7ee787" },
    ".cm-gutters": { backgroundColor: "#0d1116", color: "#6e7681", borderRight: "none" },
  },
  { dark: true },
);

// --- Sepia (subtle warm white / "sunburn") ---
const sepiaTheme = EditorView.theme(
  {
    "&": { backgroundColor: "#f5efe6", color: "#3b3228" },
    ".cm-cursor": { borderLeftColor: "#a0522d" },
    ".cm-selectionBackground, ::selection": { backgroundColor: "#e8dcc8" },
    ".cm-activeLine": { backgroundColor: "#efe8dc80" },
    ".cm-line": { padding: "0" },
    ".cm-heading-1, .cm-heading-2, .cm-heading-3, .cm-heading-4, .cm-heading-5, .cm-heading-6": { color: "#8b4513" },
    ".cm-code-block": { backgroundColor: "#efe8dc", borderRadius: "4px" },
    ".cm-blockquote": { color: "#6b7f3a" },
    ".cm-gutters": { backgroundColor: "#f5efe6", color: "#a09080", borderRight: "none" },
  },
  { dark: false },
);

export function getThemeExtension(variant: ThemeVariant): Extension {
  if (variant === "dark") return darkTheme;
  if (variant === "sepia") return sepiaTheme;
  return lightTheme;
}

export function themeExtensions(variant: ThemeVariant = "light"): Extension {
  return [baseTheme, themeCompartment.of(getThemeExtension(variant))];
}

export function fontSizeExtension(size: number): Extension {
  return EditorView.theme({ "&": { fontSize: `${size}px` } });
}

export function detectSystemTheme(): ThemeVariant {
  if (typeof window !== "undefined" && window.matchMedia) {
    return window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light";
  }
  return "light";
}
