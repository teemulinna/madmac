import { WidgetType } from "@codemirror/view";
import katex from "katex";

/**
 * Widget that renders LaTeX math using KaTeX.
 * KaTeX.renderToString produces sanitized HTML safe for DOM insertion.
 */
export class KaTeXWidget extends WidgetType {
  constructor(
    readonly tex: string,
    readonly displayMode: boolean,
  ) {
    super();
  }

  toDOM(): HTMLElement {
    const wrap = document.createElement("span");
    wrap.className = this.displayMode ? "cm-math-display" : "cm-math-inline";
    try {
      // KaTeX renderToString produces safe, sanitized HTML output
      const rendered = katex.renderToString(this.tex, {
        displayMode: this.displayMode,
        throwOnError: false,
        output: "html",
      });
      const template = document.createElement("template");
      template.innerHTML = rendered;
      wrap.appendChild(template.content);
    } catch {
      // Graceful fallback: show the raw LaTeX
      wrap.textContent = this.displayMode
        ? `$$${this.tex}$$`
        : `$${this.tex}$`;
    }
    return wrap;
  }

  eq(other: KaTeXWidget): boolean {
    return this.tex === other.tex && this.displayMode === other.displayMode;
  }

  ignoreEvent(): boolean {
    return false;
  }
}
