import { EditorView } from "@codemirror/view";
import { Extension } from "@codemirror/state";
import { Compartment } from "@codemirror/state";

export type ThemeVariant = "light" | "dark";

/**
 * Compartment for switching between light and dark themes at runtime.
 */
export const themeCompartment = new Compartment();

/**
 * Base editor theme applied to all variants.
 * Typography: system font, 16px, line-height 1.6, max-width 720px.
 */
const baseTheme = EditorView.baseTheme({
  "&": {
    fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', Helvetica, Arial, sans-serif",
    fontSize: "16px",
    lineHeight: "1.6",
  },
  ".cm-content": {
    maxWidth: "720px",
    margin: "0 auto",
    padding: "24px 16px",
    caretColor: "auto",
  },
  ".cm-scroller": {
    overflow: "auto",
  },
  ".cm-focused .cm-cursor": {
    borderLeftWidth: "2px",
  },
  ".cm-gutters": {
    display: "none",
  },
});

/**
 * Light theme for macOS light appearance.
 */
const lightTheme = EditorView.theme(
  {
    "&": {
      backgroundColor: "#ffffff",
      color: "#1d1d1f",
    },
    ".cm-content": {
      caretColor: "#007aff",
    },
    ".cm-cursor": {
      borderLeftColor: "#007aff",
    },
    ".cm-selectionBackground, ::selection": {
      backgroundColor: "#b4d5fe",
    },
    ".cm-activeLine": {
      backgroundColor: "transparent",
    },
    ".cm-line": {
      padding: "0",
    },
    // Heading styles
    ".cm-heading-1": {
      fontSize: "2em",
      fontWeight: "700",
      lineHeight: "1.2",
      marginBottom: "0.5em",
      letterSpacing: "-0.02em",
    },
    ".cm-heading-2": {
      fontSize: "1.5em",
      fontWeight: "600",
      lineHeight: "1.3",
      marginBottom: "0.4em",
      letterSpacing: "-0.01em",
    },
    ".cm-heading-3": {
      fontSize: "1.25em",
      fontWeight: "600",
      lineHeight: "1.4",
      marginBottom: "0.3em",
    },
    ".cm-heading-4": {
      fontSize: "1.125em",
      fontWeight: "600",
      lineHeight: "1.4",
    },
    ".cm-heading-5": {
      fontSize: "1.0625em",
      fontWeight: "600",
      lineHeight: "1.5",
    },
    ".cm-heading-6": {
      fontSize: "1em",
      fontWeight: "600",
      lineHeight: "1.5",
      color: "#6e6e73",
    },
    // Code blocks
    ".cm-code-block": {
      backgroundColor: "#f5f5f7",
      borderRadius: "6px",
      fontFamily: "'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace",
      fontSize: "0.9em",
      padding: "2px 0",
    },
    // Inline code
    ".cm-inline-code": {
      backgroundColor: "#f5f5f7",
      borderRadius: "3px",
      fontFamily: "'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace",
      fontSize: "0.9em",
      padding: "1px 4px",
    },
    // Links
    ".cm-link": {
      color: "#007aff",
      textDecoration: "none",
    },
    ".cm-link:hover": {
      textDecoration: "underline",
    },
    // Blockquotes
    ".cm-blockquote": {
      borderLeft: "3px solid #d1d1d6",
      paddingLeft: "16px",
      color: "#6e6e73",
    },
    // Tables
    ".cm-table-header": {
      fontWeight: "600",
    },
  },
  { dark: false },
);

/**
 * Dark theme for macOS dark appearance.
 */
const darkTheme = EditorView.theme(
  {
    "&": {
      backgroundColor: "#1e1e1e",
      color: "#e5e5e7",
    },
    ".cm-content": {
      caretColor: "#0a84ff",
    },
    ".cm-cursor": {
      borderLeftColor: "#0a84ff",
    },
    ".cm-selectionBackground, ::selection": {
      backgroundColor: "#3a3f47",
    },
    ".cm-activeLine": {
      backgroundColor: "transparent",
    },
    ".cm-line": {
      padding: "0",
    },
    // Heading styles
    ".cm-heading-1": {
      fontSize: "2em",
      fontWeight: "700",
      lineHeight: "1.2",
      marginBottom: "0.5em",
      letterSpacing: "-0.02em",
    },
    ".cm-heading-2": {
      fontSize: "1.5em",
      fontWeight: "600",
      lineHeight: "1.3",
      marginBottom: "0.4em",
      letterSpacing: "-0.01em",
    },
    ".cm-heading-3": {
      fontSize: "1.25em",
      fontWeight: "600",
      lineHeight: "1.4",
      marginBottom: "0.3em",
    },
    ".cm-heading-4": {
      fontSize: "1.125em",
      fontWeight: "600",
      lineHeight: "1.4",
    },
    ".cm-heading-5": {
      fontSize: "1.0625em",
      fontWeight: "600",
      lineHeight: "1.5",
    },
    ".cm-heading-6": {
      fontSize: "1em",
      fontWeight: "600",
      lineHeight: "1.5",
      color: "#98989d",
    },
    // Code blocks
    ".cm-code-block": {
      backgroundColor: "#2c2c2e",
      borderRadius: "6px",
      fontFamily: "'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace",
      fontSize: "0.9em",
      padding: "2px 0",
    },
    // Inline code
    ".cm-inline-code": {
      backgroundColor: "#2c2c2e",
      borderRadius: "3px",
      fontFamily: "'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace",
      fontSize: "0.9em",
      padding: "1px 4px",
    },
    // Links
    ".cm-link": {
      color: "#0a84ff",
      textDecoration: "none",
    },
    ".cm-link:hover": {
      textDecoration: "underline",
    },
    // Blockquotes
    ".cm-blockquote": {
      borderLeft: "3px solid #48484a",
      paddingLeft: "16px",
      color: "#98989d",
    },
    // Tables
    ".cm-table-header": {
      fontWeight: "600",
    },
  },
  { dark: true },
);

/**
 * Returns the theme extension for the given variant.
 */
export function getThemeExtension(variant: ThemeVariant): Extension {
  return variant === "dark" ? darkTheme : lightTheme;
}

/**
 * Returns all theme-related extensions, using the compartment for dynamic switching.
 */
export function themeExtensions(variant: ThemeVariant = "light"): Extension {
  return [baseTheme, themeCompartment.of(getThemeExtension(variant))];
}

/**
 * Detect system preference for dark mode.
 * Falls back to "light" if matchMedia is unavailable.
 */
export function detectSystemTheme(): ThemeVariant {
  if (typeof window !== "undefined" && window.matchMedia) {
    return window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light";
  }
  return "light";
}
