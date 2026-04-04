import { EditorState, Compartment, Extension } from "@codemirror/state";
import { EditorView, keymap, lineNumbers as cm6LineNumbers } from "@codemirror/view";
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands";
import { markdown, markdownLanguage } from "@codemirror/lang-markdown";
import { languages } from "@codemirror/language-data";
import { syntaxHighlighting } from "@codemirror/language";
import { search, searchKeymap } from "@codemirror/search";
import {
  themeCompartment,
  fontSizeCompartment,
  gutterCompartment,
  getThemeExtension,
  themeExtensions,
  fontSizeExtension,
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
import { renderMarkdownToHTML, READING_MODE_CSS } from "./reading-mode";
import katex from "katex";

// Expose katex globally for Reading Mode HTML processing
(window as any).katex = katex;

export type EditorMode = "reading" | "fluid";

// Compartments for dynamic reconfiguration
const highlightCompartment = new Compartment();
const modeCompartment = new Compartment();

// Dual-layer state
let view: EditorView | null = null;
let currentMode: EditorMode = "reading";
let currentTheme: ThemeVariant = "light";
let currentFontSize: number = 14;
let rawContent: string = "";
let cm6Container: HTMLElement | null = null;
let readingContainer: HTMLElement | null = null;

function highlightExtension(variant: ThemeVariant): Extension {
  return syntaxHighlighting(
    variant === "dark" ? darkMarkdownStyle : lightMarkdownStyle,
  );
}

function modeExtensions(mode: EditorMode): Extension {
  return mode === "reading"
    ? [EditorView.editable.of(false), EditorState.readOnly.of(true)]
    : [EditorView.editable.of(true), EditorState.readOnly.of(false)];
}

let cssInjected = false;
function injectReadingCSS(): void {
  if (cssInjected) return;
  const style = document.createElement("style");
  style.id = "macmd-reading-mode-css";
  style.textContent = READING_MODE_CSS;
  document.head.appendChild(style);
  cssInjected = true;
}

// --- Reading mode theme CSS ---
const READING_THEME_VARS: Record<ThemeVariant, Record<string, string>> = {
  light: {
    "--text-primary": "#1d1d1f",
    "--text-secondary": "#6e6e73",
    "--bg-primary": "#ffffff",
    "--bg-secondary": "#f5f5f7",
    "--bg-code": "#f5f5f7",
    "--border-color": "#d2d2d7",
    "--accent-color": "#0066cc",
    "--heading-color": "#1d1d1f",
    "--blockquote-border": "#0066cc",
    "--table-border": "#d2d2d7",
    "--table-header-bg": "#f5f5f7",
    "--hr-color": "#d2d2d7",
  },
  dark: {
    "--text-primary": "#f5f5f7",
    "--text-secondary": "#86868b",
    "--bg-primary": "#1d1d1f",
    "--bg-secondary": "#2c2c2e",
    "--bg-code": "#2c2c2e",
    "--border-color": "#48484a",
    "--accent-color": "#4da3ff",
    "--heading-color": "#f5f5f7",
    "--blockquote-border": "#4da3ff",
    "--table-border": "#48484a",
    "--table-header-bg": "#2c2c2e",
    "--hr-color": "#48484a",
  },
  sepia: {
    "--text-primary": "#3b3228",
    "--text-secondary": "#7a6a52",
    "--bg-primary": "#f5efe6",
    "--bg-secondary": "#efe8dc",
    "--bg-code": "#efe8dc",
    "--border-color": "#e0d8cc",
    "--accent-color": "#8b4513",
    "--heading-color": "#3b3228",
    "--blockquote-border": "#8b4513",
    "--table-border": "#e0d8cc",
    "--table-header-bg": "#f5f0ea",
    "--hr-color": "#e0d8cc",
  },
};

function applyReadingTheme(theme: ThemeVariant): void {
  const vars = READING_THEME_VARS[theme];
  const root = document.documentElement;
  for (const [key, value] of Object.entries(vars)) {
    root.style.setProperty(key, value);
  }
  document.body.style.backgroundColor = vars["--bg-primary"];
}

function renderReadingView(): void {
  if (!readingContainer) return;
  const content = view ? view.state.doc.toString() : rawContent;
  readingContainer.innerHTML = renderMarkdownToHTML(content);
  processMermaidInHTML(readingContainer);
  processKaTeXInHTML(readingContainer);
}

let mermaidInitialized = false;

async function processMermaidInHTML(parent: HTMLElement): Promise<void> {
  const mermaid = (window as any).mermaid;
  if (!mermaid) return;

  if (!mermaidInitialized) {
    mermaidInitialized = true;
    mermaid.initialize({
      startOnLoad: false,
      theme: "neutral",
      securityLevel: "loose",
    });
  }

  const codeBlocks = parent.querySelectorAll("code.language-mermaid");
  for (let i = 0; i < codeBlocks.length; i++) {
    const code = codeBlocks[i];
    const pre = code.parentElement;
    const wrapper = pre?.parentElement;
    if (!wrapper) continue;

    const source = code.textContent || "";
    try {
      const id = "mermaid-reading-" + i + "-" + Date.now();
      const { svg } = await mermaid.render(id, source);
      const container = document.createElement("div");
      container.className = "mermaid-diagram";
      container.style.textAlign = "center";
      container.style.margin = "1em 0";
      container.innerHTML = svg;
      wrapper.replaceWith(container);
    } catch {
      // Leave code block as-is on error
    }
  }
}

function processKaTeXInHTML(parent: HTMLElement): void {
  const katex = (window as any).katex;
  if (!katex) return;

  const article = parent.querySelector(".reading-mode");
  if (!article) return;

  const walker = document.createTreeWalker(article, NodeFilter.SHOW_TEXT);
  const replacements: { node: Text; newNodes: Node[] }[] = [];

  let textNode: Text | null;
  while ((textNode = walker.nextNode() as Text | null)) {
    if (textNode.parentElement?.closest("pre, code")) continue;

    const text = textNode.textContent || "";
    const regex = /\$\$([\s\S]+?)\$\$|\$([^$\n]+?)\$/g;
    let match;
    let lastIndex = 0;
    const fragments: Node[] = [];
    let hasMatch = false;

    while ((match = regex.exec(text)) !== null) {
      hasMatch = true;
      if (match.index > lastIndex) {
        fragments.push(
          document.createTextNode(text.slice(lastIndex, match.index)),
        );
      }

      const isDisplay = match[1] !== undefined;
      const tex = isDisplay ? match[1] : match[2];

      try {
        const span = document.createElement(isDisplay ? "div" : "span");
        span.innerHTML = katex.renderToString(tex.trim(), {
          displayMode: isDisplay,
          throwOnError: false,
        });
        if (isDisplay) {
          span.className = "katex-display";
          span.style.textAlign = "center";
          span.style.margin = "1em 0";
        }
        fragments.push(span);
      } catch {
        fragments.push(document.createTextNode(match[0]));
      }
      lastIndex = regex.lastIndex;
    }

    if (hasMatch) {
      if (lastIndex < text.length) {
        fragments.push(document.createTextNode(text.slice(lastIndex)));
      }
      replacements.push({ node: textNode, newNodes: fragments });
    }
  }

  for (const { node, newNodes } of replacements) {
    const parentNode = node.parentNode;
    if (!parentNode) continue;
    for (const newNode of newNodes) {
      parentNode.insertBefore(newNode, node);
    }
    parentNode.removeChild(node);
  }
}

function showLayer(mode: EditorMode): void {
  if (!cm6Container || !readingContainer) return;
  if (mode === "reading") {
    cm6Container.style.display = "none";
    readingContainer.style.display = "block";
    renderReadingView();
  } else {
    readingContainer.style.display = "none";
    cm6Container.style.display = "block";
    view?.focus();
  }
}

export function createEditor(
  parent: HTMLElement,
  content: string = "",
  mode: EditorMode = "reading",
  theme?: ThemeVariant,
): EditorView {
  currentMode = mode;
  currentTheme = theme ?? detectSystemTheme();
  currentFontSize = 14;
  rawContent = content;

  injectReadingCSS();
  applyReadingTheme(currentTheme);

  cm6Container = document.createElement("div");
  cm6Container.className = "macmd-cm6-container";
  cm6Container.style.padding = "32px 48px";
  readingContainer = document.createElement("div");
  readingContainer.className = "macmd-reading-container";
  parent.appendChild(cm6Container);
  parent.appendChild(readingContainer);

  const state = EditorState.create({
    doc: content,
    extensions: [
      history(),
      keymap.of([...defaultKeymap, ...historyKeymap, ...searchKeymap]),
      markdown({ base: markdownLanguage, codeLanguages: languages }),
      highlightCompartment.of(highlightExtension(currentTheme)),
      modeCompartment.of(modeExtensions(mode)),
      fontSizeCompartment.of(fontSizeExtension(currentFontSize)),
      gutterCompartment.of([]),
      themeExtensions(currentTheme),
      headingLineClasses,
      search(),
      EditorView.lineWrapping,
      contentChangeNotifier(),
    ],
  });

  view = new EditorView({ state, parent: cm6Container });
  showLayer(mode);
  notifyReady();
  return view;
}

export function setContent(content: string): void {
  rawContent = content;
  if (view) {
    view.dispatch({
      changes: { from: 0, to: view.state.doc.length, insert: content },
    });
  }
  if (currentMode === "reading") {
    renderReadingView();
  }
}

export function getContent(): string {
  if (view) return view.state.doc.toString();
  return rawContent;
}

export function setMode(mode: EditorMode): void {
  if (mode === currentMode) return;
  currentMode = mode;
  if (view) {
    view.dispatch({
      effects: modeCompartment.reconfigure(modeExtensions(mode)),
    });
  }
  showLayer(mode);
  notifyModeChanged(mode);
}

export function setTheme(theme: ThemeVariant): void {
  currentTheme = theme;
  applyReadingTheme(theme);
  if (view) {
    view.dispatch({
      effects: [
        themeCompartment.reconfigure(getThemeExtension(theme)),
        highlightCompartment.reconfigure(highlightExtension(theme)),
      ],
    });
  }
  if (currentMode === "reading") {
    renderReadingView();
  }
  notifyThemeChanged(theme);
}

export function setFontSize(size: number): void {
  currentFontSize = Math.max(10, Math.min(32, size));
  if (view) {
    view.dispatch({
      effects: fontSizeCompartment.reconfigure(
        fontSizeExtension(currentFontSize),
      ),
    });
  }
}

export function getFontSize(): number {
  return currentFontSize;
}

export function showLineNumbers(show: boolean): void {
  if (!view) return;
  view.dispatch({
    effects: gutterCompartment.reconfigure(show ? cm6LineNumbers() : []),
  });
}

export function getMode(): EditorMode {
  return currentMode;
}

export function getTheme(): ThemeVariant {
  return currentTheme;
}

export function getView(): EditorView | null {
  return view;
}
