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
import { renderMarkdownToHTML, READING_MODE_CSS } from "./reading-mode";
import katex from "katex";

// Expose katex globally for Reading Mode HTML processing
(window as any).katex = katex;

export type EditorMode = "reading" | "fluid";

const highlightCompartment = new Compartment();

let view: EditorView | null = null;
let currentMode: EditorMode = "reading";
let currentTheme: ThemeVariant = "light";
let rawContent: string = "";
let parentElement: HTMLElement | null = null;

function highlightExtension(variant: ThemeVariant): Extension {
  return syntaxHighlighting(
    variant === "dark" ? darkMarkdownStyle : lightMarkdownStyle,
  );
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

function showReadingMode(parent: HTMLElement, content: string): void {
  injectReadingCSS();
  if (view) {
    view.destroy();
    view = null;
  }
  parent.innerHTML = renderMarkdownToHTML(content);
  processMermaidInHTML(parent);
  processKaTeXInHTML(parent);
}

async function processMermaidInHTML(parent: HTMLElement): Promise<void> {
  const mermaid = (window as any).mermaid;
  if (!mermaid) return;

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

function showFluidMode(
  parent: HTMLElement,
  content: string,
  theme: ThemeVariant,
): EditorView {
  parent.innerHTML = "";

  const state = EditorState.create({
    doc: content,
    extensions: [
      history(),
      keymap.of([...defaultKeymap, ...historyKeymap, ...searchKeymap]),
      markdown({ base: markdownLanguage, codeLanguages: languages }),
      highlightCompartment.of(highlightExtension(theme)),
      themeExtensions(theme),
      headingLineClasses,
      search(),
      EditorView.lineWrapping,
      EditorView.editable.of(true),
      fluidMode(),
      mermaidExtension(),
      mathExtension(),
      contentChangeNotifier(),
    ],
  });

  return new EditorView({ state, parent });
}

export function createEditor(
  parent: HTMLElement,
  content: string = "",
  mode: EditorMode = "reading",
  theme?: ThemeVariant,
): EditorView {
  currentMode = mode;
  currentTheme = theme ?? detectSystemTheme();
  rawContent = content;
  parentElement = parent;

  if (mode === "reading") {
    showReadingMode(parent, content);
    // Hidden CM6 to satisfy API contract (getContent, etc.)
    const hiddenDiv = document.createElement("div");
    hiddenDiv.style.display = "none";
    parent.appendChild(hiddenDiv);
    const state = EditorState.create({ doc: content });
    view = new EditorView({ state, parent: hiddenDiv });
  } else {
    view = showFluidMode(parent, content, currentTheme);
  }

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
  if (currentMode === "reading" && parentElement) {
    showReadingMode(parentElement, content);
    const hiddenDiv = document.createElement("div");
    hiddenDiv.style.display = "none";
    parentElement.appendChild(hiddenDiv);
    if (view) view.destroy();
    const state = EditorState.create({ doc: content });
    view = new EditorView({ state, parent: hiddenDiv });
  }
}

export function getContent(): string {
  if (currentMode === "fluid" && view) {
    return view.state.doc.toString();
  }
  return rawContent;
}

export function setMode(mode: EditorMode): void {
  if (mode === currentMode || !parentElement) return;

  if (currentMode === "fluid" && view) {
    rawContent = view.state.doc.toString();
  }

  currentMode = mode;

  if (mode === "reading") {
    if (view) {
      view.destroy();
      view = null;
    }
    showReadingMode(parentElement, rawContent);
    const hiddenDiv = document.createElement("div");
    hiddenDiv.style.display = "none";
    parentElement.appendChild(hiddenDiv);
    const state = EditorState.create({ doc: rawContent });
    view = new EditorView({ state, parent: hiddenDiv });
  } else {
    view = showFluidMode(parentElement, rawContent, currentTheme);
  }

  notifyModeChanged(mode);
}

export function setTheme(theme: ThemeVariant): void {
  currentTheme = theme;
  if (currentMode === "fluid" && view) {
    view.dispatch({
      effects: [
        themeCompartment.reconfigure(getThemeExtension(theme)),
        highlightCompartment.reconfigure(highlightExtension(theme)),
      ],
    });
  }
  notifyThemeChanged(theme);
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
