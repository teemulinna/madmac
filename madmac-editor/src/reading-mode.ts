import { Marked } from "marked";
import type { Tokens } from "marked";
import hljs from "highlight.js/lib/core";
import python from "highlight.js/lib/languages/python";
import javascript from "highlight.js/lib/languages/javascript";
import typescript from "highlight.js/lib/languages/typescript";
import rust from "highlight.js/lib/languages/rust";
import swift from "highlight.js/lib/languages/swift";
import bash from "highlight.js/lib/languages/bash";
import json from "highlight.js/lib/languages/json";
import yaml from "highlight.js/lib/languages/yaml";
import xml from "highlight.js/lib/languages/xml";
import css from "highlight.js/lib/languages/css";
import sql from "highlight.js/lib/languages/sql";
import go from "highlight.js/lib/languages/go";
import java from "highlight.js/lib/languages/java";
import cpp from "highlight.js/lib/languages/cpp";
import ruby from "highlight.js/lib/languages/ruby";
import markdown from "highlight.js/lib/languages/markdown";

// Register languages
hljs.registerLanguage("python", python);
hljs.registerLanguage("javascript", javascript);
hljs.registerLanguage("js", javascript);
hljs.registerLanguage("typescript", typescript);
hljs.registerLanguage("ts", typescript);
hljs.registerLanguage("rust", rust);
hljs.registerLanguage("swift", swift);
hljs.registerLanguage("bash", bash);
hljs.registerLanguage("sh", bash);
hljs.registerLanguage("shell", bash);
hljs.registerLanguage("zsh", bash);
hljs.registerLanguage("json", json);
hljs.registerLanguage("yaml", yaml);
hljs.registerLanguage("yml", yaml);
hljs.registerLanguage("xml", xml);
hljs.registerLanguage("html", xml);
hljs.registerLanguage("css", css);
hljs.registerLanguage("sql", sql);
hljs.registerLanguage("go", go);
hljs.registerLanguage("java", java);
hljs.registerLanguage("cpp", cpp);
hljs.registerLanguage("c", cpp);
hljs.registerLanguage("ruby", ruby);
hljs.registerLanguage("rb", ruby);
hljs.registerLanguage("markdown", markdown);
hljs.registerLanguage("md", markdown);

/**
 * Reading Mode: renders markdown to beautiful HTML.
 * No CM6 editor — just a styled web page.
 */

const marked = new Marked();

// Only override the code renderer for syntax highlighting + language label.
// Do NOT override table, listitem, etc. — marked handles inline formatting
// (bold, italic, strikethrough) automatically. Custom renderers that accept
// raw text break this by bypassing inline token processing.
marked.use({
  renderer: {
    code({ text, lang }: Tokens.Code): string {
      // Skip mermaid — handled separately
      if (lang === "mermaid") {
        const escaped = text
          .replace(/&/g, "&amp;")
          .replace(/</g, "&lt;")
          .replace(/>/g, "&gt;");
        return `<div class="code-block-wrapper"><pre><code class="language-mermaid">${escaped}</code></pre></div>`;
      }

      const langLabel = lang
        ? `<span class="code-lang-label">${lang}</span>`
        : "";

      let highlighted: string;
      if (lang && hljs.getLanguage(lang)) {
        highlighted = hljs.highlight(text, { language: lang }).value;
      } else if (lang) {
        // Unknown language — try auto-detection
        try {
          highlighted = hljs.highlightAuto(text).value;
        } catch {
          highlighted = text
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
        }
      } else {
        highlighted = text
          .replace(/&/g, "&amp;")
          .replace(/</g, "&lt;")
          .replace(/>/g, "&gt;");
      }

      return `<div class="code-block-wrapper">${langLabel}<pre><code class="hljs${lang ? ` language-${lang}` : ""}">${highlighted}</code></pre></div>`;
    },
  },
  // Enable GFM extensions (strikethrough, tables, etc.)
  gfm: true,
  breaks: false,
});

/**
 * Render markdown string to styled HTML for Reading Mode.
 */
export function renderMarkdownToHTML(markdown: string): string {
  const bodyHTML = marked.parse(markdown) as string;

  return `
    <article class="reading-mode">
      ${bodyHTML}
    </article>
  `;
}

/**
 * CSS for Reading Mode — designed to look like VS Code's markdown preview
 * but with macmd's own personality.
 */
export const READING_MODE_CSS = `
  /* Unified zoom: --md-zoom drives text, headings, code, AND SVG diagrams.
     Default 1.0 = 100%. Set via MacmdEditor.setZoom() from Swift Cmd+/-/0. */
  :root { --md-zoom: 1; }

  .reading-mode {
    padding: 32px 48px;
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
    font-size: calc(16px * var(--md-zoom));
    line-height: 1.7;
    color: var(--text-primary);
  }

  /* SVG diagrams (Mermaid) — CSS zoom property scales element AND its layout box.
     Supported in WebKit/Chrome/Edge. The cleanest way to scale fixed-dimension
     elements like Mermaid SVGs while preserving page flow. */
  .reading-mode .mermaid-diagram,
  .reading-mode .mermaid-diagram svg,
  .reading-mode svg.mermaid {
    zoom: var(--md-zoom);
  }

  /* KaTeX math (inline + display): font-size scales because we're inside
     .reading-mode which already has calc(16px * --md-zoom). KaTeX uses em-units
     internally so it scales automatically. No override needed. */

  :root {
    --text-primary: #1d1d1f;
    --text-secondary: #6e6e73;
    --bg-primary: #ffffff;
    --bg-secondary: #f5f5f7;
    --bg-code: #f5f5f7;
    --border-color: #d2d2d7;
    --accent-color: #0066cc;
    --heading-color: #1d1d1f;
    --code-text: #1d1d1f;
    --blockquote-border: #0066cc;
    --table-border: #d2d2d7;
    --table-header-bg: #f5f5f7;
    --hr-color: #d2d2d7;
    --checkbox-accent: #34c759;
  }

  @media (prefers-color-scheme: dark) {
    :root {
      --text-primary: #f5f5f7;
      --text-secondary: #86868b;
      --bg-primary: #1d1d1f;
      --bg-secondary: #2c2c2e;
      --bg-code: #2c2c2e;
      --border-color: #48484a;
      --accent-color: #4da3ff;
      --heading-color: #f5f5f7;
      --code-text: #f5f5f7;
      --blockquote-border: #4da3ff;
      --table-border: #48484a;
      --table-header-bg: #2c2c2e;
      --hr-color: #48484a;
      --checkbox-accent: #30d158;
    }
  }

  body {
    background: var(--bg-primary);
    margin: 0;
  }

  /* Headings */
  .reading-mode h1 {
    font-size: 2em;
    font-weight: 700;
    color: var(--heading-color);
    margin: 0.5em 0 0.3em;
    letter-spacing: -0.02em;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 0.3em;
  }
  .reading-mode h2 {
    font-size: 1.5em;
    font-weight: 600;
    color: var(--heading-color);
    margin: 1.2em 0 0.3em;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 0.2em;
  }
  .reading-mode h3 {
    font-size: 1.25em;
    font-weight: 600;
    color: var(--heading-color);
    margin: 1em 0 0.3em;
  }
  .reading-mode h4, .reading-mode h5, .reading-mode h6 {
    font-size: 1em;
    font-weight: 600;
    color: var(--heading-color);
    margin: 1em 0 0.2em;
  }

  /* Paragraphs */
  .reading-mode p {
    margin: 0.8em 0;
  }

  /* Links */
  .reading-mode a {
    color: var(--accent-color);
    text-decoration: none;
  }
  .reading-mode a:hover {
    text-decoration: underline;
  }

  /* Strong / Em */
  .reading-mode strong { font-weight: 600; }
  .reading-mode em { font-style: italic; }
  .reading-mode del { text-decoration: line-through; color: var(--text-secondary); }

  /* Inline code */
  .reading-mode code {
    font-family: "SF Mono", "Menlo", "Monaco", monospace;
    font-size: 0.9em;
    background: var(--bg-code);
    padding: 0.15em 0.4em;
    border-radius: 4px;
  }

  /* Code blocks */
  .reading-mode .code-block-wrapper {
    position: relative;
    margin: 1em 0;
  }
  .reading-mode .code-lang-label {
    position: absolute;
    top: 8px;
    right: 12px;
    font-size: 0.75em;
    color: var(--text-secondary);
    font-family: "SF Mono", "Menlo", monospace;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  .reading-mode pre {
    background: var(--bg-code);
    border-radius: 8px;
    padding: 16px 20px;
    overflow-x: auto;
    margin: 0;
  }
  .reading-mode pre code {
    background: none;
    padding: 0;
    font-size: 0.875em;
    line-height: 1.5;
    color: var(--code-text);
  }

  /* Blockquotes */
  .reading-mode blockquote {
    border-left: 3px solid var(--blockquote-border);
    margin: 1em 0;
    padding: 0.5em 0 0.5em 20px;
    color: var(--text-secondary);
  }
  .reading-mode blockquote p { margin: 0.3em 0; }

  /* Lists */
  .reading-mode ul, .reading-mode ol {
    padding-left: 2em;
    margin: 0.5em 0;
  }
  .reading-mode li {
    margin: 0.25em 0;
  }
  .reading-mode li::marker {
    color: var(--text-secondary);
  }

  /* Task lists */
  .reading-mode .task-item {
    list-style: none;
    margin-left: -1.5em;
  }
  .reading-mode .task-item input[type="checkbox"] {
    margin-right: 0.5em;
    accent-color: var(--checkbox-accent);
  }

  /* Tables */
  .reading-mode table {
    border-collapse: collapse;
    width: 100%;
    margin: 1em 0;
    font-size: 0.95em;
  }
  .reading-mode th {
    background: var(--table-header-bg);
    font-weight: 600;
    text-align: left;
    padding: 8px 12px;
    border-bottom: 2px solid var(--table-border);
  }
  .reading-mode td {
    padding: 8px 12px;
    border-bottom: 1px solid var(--table-border);
  }
  .reading-mode tr:last-child td {
    border-bottom: none;
  }

  /* Horizontal rule */
  .reading-mode hr {
    border: none;
    height: 1px;
    background: var(--hr-color);
    margin: 2em 0;
  }

  /* Images */
  .reading-mode img {
    max-width: 100%;
    border-radius: 8px;
    margin: 1em 0;
  }

  /* KaTeX */
  .reading-mode .katex { font-size: 1.1em; }
  .reading-mode .katex-display { margin: 1em 0; text-align: center; }

  /* highlight.js syntax colors — dark theme (matches macOS dark) */
  @media (prefers-color-scheme: dark) {
    .hljs-keyword { color: #ff7ab2; }
    .hljs-built_in { color: #dabaff; }
    .hljs-string { color: #ff8170; }
    .hljs-number { color: #d9c97c; }
    .hljs-comment { color: #7f8c98; font-style: italic; }
    .hljs-function { color: #67b7a4; }
    .hljs-title { color: #67b7a4; }
    .hljs-params { color: #acf2e4; }
    .hljs-type { color: #dabaff; }
    .hljs-attr { color: #d9c97c; }
    .hljs-selector-tag { color: #ff7ab2; }
    .hljs-selector-class { color: #67b7a4; }
    .hljs-literal { color: #ff7ab2; }
    .hljs-meta { color: #7f8c98; }
    .hljs-variable { color: #acf2e4; }
  }

  /* highlight.js syntax colors — light theme */
  @media (prefers-color-scheme: light) {
    .hljs-keyword { color: #ad3da4; }
    .hljs-built_in { color: #804fb8; }
    .hljs-string { color: #d12f1b; }
    .hljs-number { color: #272ad8; }
    .hljs-comment { color: #707f8c; font-style: italic; }
    .hljs-function { color: #4b9b8f; }
    .hljs-title { color: #4b9b8f; }
    .hljs-params { color: #4b9b8f; }
    .hljs-type { color: #804fb8; }
    .hljs-attr { color: #947100; }
    .hljs-selector-tag { color: #ad3da4; }
    .hljs-selector-class { color: #4b9b8f; }
    .hljs-literal { color: #ad3da4; }
    .hljs-meta { color: #707f8c; }
    .hljs-variable { color: #4b9b8f; }
  }
`;
