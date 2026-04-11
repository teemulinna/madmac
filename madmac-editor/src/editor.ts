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
  processKrokiInHTML(readingContainer);
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

  // Apply current zoom to newly rendered SVGs
  applyZoomToMermaidSvgs();
}

// ---- Kroki diagram rendering (PlantUML, Graphviz, D2, etc.) ----

/** Languages supported via Kroki API. Mermaid is handled separately (client-side). */
export const KROKI_LANGUAGES = [
  "plantuml", "graphviz", "dot", "d2", "ditaa", "erd",
  "excalidraw", "nomnoml", "pikchr", "structurizr",
  "svgbob", "umlet", "vega", "vegalite", "wavedrom",
  "bytefield", "blockdiag", "seqdiag", "actdiag",
  "nwdiag", "rackdiag", "packetdiag",
] as const;

const KROKI_BASE_URL = "https://kroki.io";

/**
 * Render a diagram via Kroki API.
 * Returns SVG string on success, null on failure (network error, bad syntax, etc.)
 */
export async function renderKrokiDiagram(
  language: string,
  source: string,
): Promise<string | null> {
  // Map aliases
  const lang = language === "dot" ? "graphviz" : language;
  try {
    const response = await fetch(`${KROKI_BASE_URL}/${lang}/svg`, {
      method: "POST",
      headers: { "Content-Type": "text/plain" },
      body: source,
    });
    if (!response.ok) return null;
    return await response.text();
  } catch {
    return null;
  }
}

/** Process Kroki-supported code blocks in reading-mode HTML. */
async function processKrokiInHTML(parent: HTMLElement): Promise<void> {
  const krokiSet = new Set<string>(KROKI_LANGUAGES);
  const codeBlocks = parent.querySelectorAll("code[class*='language-']");

  for (let i = 0; i < codeBlocks.length; i++) {
    const code = codeBlocks[i];
    const classMatch = code.className.match(/language-(\S+)/);
    if (!classMatch) continue;
    const lang = classMatch[1].toLowerCase();
    if (!krokiSet.has(lang)) continue;

    const pre = code.parentElement;
    const wrapper = pre?.parentElement;
    if (!wrapper) continue;

    const source = code.textContent || "";
    const svg = await renderKrokiDiagram(lang, source);

    if (svg) {
      const container = document.createElement("div");
      container.className = "kroki-diagram mermaid-diagram"; // reuse mermaid-diagram class for zoom
      container.style.textAlign = "center";
      container.style.margin = "1em 0";
      container.innerHTML = svg;
      wrapper.replaceWith(container);
    } else {
      // Show a subtle offline/error hint below the code block
      const hint = document.createElement("div");
      hint.style.cssText = "font-size: 12px; color: #999; text-align: center; padding: 4px;";
      hint.textContent = "Diagram rendering requires internet connection";
      wrapper.appendChild(hint);
    }
  }

  // Apply zoom to newly rendered Kroki SVGs
  applyZoomToMermaidSvgs();
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

  // Reading mode Cmd+C → copies selection as markdown
  readingContainer.addEventListener("copy", (e: ClipboardEvent) => {
    if (currentMode !== "reading") return;
    const sel = window.getSelection();
    if (!sel || sel.isCollapsed) return;

    const range = sel.getRangeAt(0);
    const div = document.createElement("div");
    div.appendChild(range.cloneContents());
    const selectedHtml = div.innerHTML;
    const md = htmlToMarkdown(selectedHtml);

    if (md) {
      e.preventDefault();
      e.clipboardData?.setData("text/plain", md);
      e.clipboardData?.setData("text/html", selectedHtml);
    }
  });

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

// ---- Unified zoom (text + diagrams + math) ----

let currentZoom = 1.0;

/**
 * Set the unified viewer zoom level.
 * Drives:
 *  1. --md-zoom CSS custom property → text, headings, code (via calc + em)
 *  2. KaTeX math (inherits from font-size in em units)
 *  3. Mermaid SVGs — width set directly via JS (CSS zoom unreliable on SVG in WebKit)
 *
 * Range: 0.5 (50%) to 3.0 (300%). Values outside are clamped.
 */
export function setZoom(level: number): void {
  currentZoom = Math.max(0.5, Math.min(3.0, level));
  if (typeof document !== "undefined") {
    document.documentElement.style.setProperty("--md-zoom", String(currentZoom));
    const svgCount = applyZoomToMermaidSvgs();
    // Diagnostic: log via console (visible in Web Inspector)
    console.log(`[MadMac] setZoom(${currentZoom}) — scaled ${svgCount} mermaid SVG(s)`);
  }
}

export function getZoom(): number {
  return currentZoom;
}

export function resetZoom(): void {
  setZoom(1.0);
}

/**
 * Scale all Mermaid SVGs to the current zoom level.
 * Mermaid renders SVGs with explicit width/height. CSS zoom is unreliable on
 * SVG in WebKit, so we set the width attribute directly. The viewBox preserves
 * the aspect ratio so text inside the SVG scales proportionally too.
 */
function applyZoomToMermaidSvgs(): number {
  const svgs = document.querySelectorAll<SVGSVGElement>(
    '.mermaid-diagram svg, svg[id^="mermaid-"]',
  );
  svgs.forEach((svg) => {
    // Capture intrinsic width on first encounter.
    // Priority order: viewBox (intrinsic) → width attr (if numeric px) → bounding rect.
    // Mermaid's style.maxWidth is often "100%" — useless for our purposes.
    if (!svg.dataset.originalWidth) {
      let naturalWidth = NaN;

      // 1. Try viewBox — most reliable, gives intrinsic dimensions
      const viewBox = svg.getAttribute("viewBox");
      if (viewBox) {
        const parts = viewBox.trim().split(/\s+/).map(parseFloat);
        if (parts.length === 4 && !isNaN(parts[2]) && parts[2] > 0) {
          naturalWidth = parts[2];
        }
      }

      // 2. Try width attribute (only if it's a plain number, not a percentage)
      if (isNaN(naturalWidth)) {
        const widthAttr = svg.getAttribute("width");
        if (widthAttr && !widthAttr.endsWith("%")) {
          const parsed = parseFloat(widthAttr);
          if (!isNaN(parsed) && parsed > 10) {
            naturalWidth = parsed;
          }
        }
      }

      // 3. Last resort: bounding rect (must be in DOM and laid out)
      if (isNaN(naturalWidth) || naturalWidth <= 10) {
        const rect = svg.getBoundingClientRect().width;
        if (rect > 10) {
          naturalWidth = rect;
        }
      }

      if (!isNaN(naturalWidth) && naturalWidth > 0) {
        svg.dataset.originalWidth = String(naturalWidth);
      }
    }

    const natural = parseFloat(svg.dataset.originalWidth || "0");
    if (natural > 0) {
      const scaled = natural * currentZoom;
      svg.style.width = `${scaled}px`;
      svg.style.height = "auto";
      svg.style.maxWidth = "none";
    }
  });
  return svgs.length;
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

/** Get the selected HTML from reading mode */
export function copySelectionAsRichText(): string {
  const sel = window.getSelection();
  if (!sel || sel.isCollapsed) return "";
  const range = sel.getRangeAt(0);
  const div = document.createElement("div");
  div.appendChild(range.cloneContents());
  return div.innerHTML;
}

/** Convert HTML to markdown (simple, covers common elements) */
function htmlToMarkdown(html: string): string {
  const doc = new DOMParser().parseFromString(html, "text/html");

  function walk(node: Node): string {
    if (node.nodeType === Node.TEXT_NODE) {
      return node.textContent || "";
    }
    if (node.nodeType !== Node.ELEMENT_NODE) return "";
    const el = node as HTMLElement;
    const tag = el.tagName.toLowerCase();
    const children = Array.from(el.childNodes).map(walk).join("");

    switch (tag) {
      case "h1": return `# ${children}\n\n`;
      case "h2": return `## ${children}\n\n`;
      case "h3": return `### ${children}\n\n`;
      case "h4": return `#### ${children}\n\n`;
      case "h5": return `##### ${children}\n\n`;
      case "h6": return `###### ${children}\n\n`;
      case "p": return `${children}\n\n`;
      case "strong": case "b": return `**${children}**`;
      case "em": case "i": return `*${children}*`;
      case "del": case "s": return `~~${children}~~`;
      case "code":
        if (el.parentElement?.tagName === "PRE") return children;
        return `\`${children}\``;
      case "pre": {
        const code = el.querySelector("code");
        const lang = code?.className?.match(/language-(\w+)/)?.[1] || "";
        const text = code?.textContent || children;
        return `\`\`\`${lang}\n${text}\n\`\`\`\n\n`;
      }
      case "a": return `[${children}](${el.getAttribute("href") || ""})`;
      case "img": return `![${el.getAttribute("alt") || ""}](${el.getAttribute("src") || ""})`;
      case "blockquote": return children.split("\n").map(l => l ? `> ${l}` : ">").join("\n") + "\n\n";
      case "ul": case "ol": return `${children}\n`;
      case "li": {
        const prefix = el.parentElement?.tagName === "OL"
          ? `${Array.from(el.parentElement!.children).indexOf(el) + 1}. `
          : "- ";
        return `${prefix}${children.trim()}\n`;
      }
      case "hr": return "---\n\n";
      case "br": return "\n";
      case "table": return children;
      case "thead": case "tbody": return children;
      case "tr": {
        const cells = Array.from(el.children).map(c => walk(c).trim());
        const row = `| ${cells.join(" | ")} |`;
        // Add header separator after thead tr
        if (el.parentElement?.tagName === "THEAD") {
          const sep = cells.map(() => "---").join(" | ");
          return `${row}\n| ${sep} |\n`;
        }
        return `${row}\n`;
      }
      case "th": case "td": return children;
      case "div": case "span": case "article": case "section":
        return children;
      default: return children;
    }
  }

  return walk(doc.body).replace(/\n{3,}/g, "\n\n").trim();
}

export function getView(): EditorView | null {
  return view;
}
