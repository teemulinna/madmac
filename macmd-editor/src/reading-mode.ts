import { Marked } from "marked";
import type { Tokens } from "marked";

/**
 * Reading Mode: renders markdown to beautiful HTML.
 * No CM6 editor — just a styled web page.
 *
 * This is what users see when they open a .md file from Finder.
 * CM6 is only used in Fluid Mode (Cmd+E).
 */

const marked = new Marked();

// Custom renderer for better output
marked.use({
  renderer: {
    // Code blocks with language label
    code({ text, lang }: Tokens.Code): string {
      const langClass = lang ? ` class="language-${lang}"` : "";
      const langLabel = lang
        ? `<span class="code-lang-label">${lang}</span>`
        : "";
      const escaped = text
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");
      return `<div class="code-block-wrapper">${langLabel}<pre><code${langClass}>${escaped}</code></pre></div>`;
    },

    // Tables with proper styling
    table({ header, rows }: Tokens.Table): string {
      const headerCells = header
        .map(
          (cell) =>
            `<th style="text-align:${cell.align || "left"}">${cell.text}</th>`,
        )
        .join("");
      const bodyRows = rows
        .map(
          (row) =>
            `<tr>${row.map((cell) => `<td style="text-align:${cell.align || "left"}">${cell.text}</td>`).join("")}</tr>`,
        )
        .join("");
      return `<table><thead><tr>${headerCells}</tr></thead><tbody>${bodyRows}</tbody></table>`;
    },

    // Checkboxes in list items
    listitem({ text, task, checked }: Tokens.ListItem): string {
      if (task) {
        const checkbox = checked
          ? '<input type="checkbox" checked disabled>'
          : '<input type="checkbox" disabled>';
        return `<li class="task-item">${checkbox} ${text}</li>`;
      }
      return `<li>${text}</li>`;
    },
  },
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
  .reading-mode {
    max-width: 720px;
    margin: 0 auto;
    padding: 32px 48px;
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
    font-size: 16px;
    line-height: 1.7;
    color: var(--text-primary);
  }

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

  /* MathJax/KaTeX placeholder */
  .reading-mode .katex { font-size: 1.1em; }
  .reading-mode .katex-display { margin: 1em 0; text-align: center; }
`;
