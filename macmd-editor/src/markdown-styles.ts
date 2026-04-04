import { HighlightStyle } from "@codemirror/language";
import { tags } from "@lezer/highlight";
import { ViewPlugin, DecorationSet, Decoration, EditorView } from "@codemirror/view";
import { syntaxTree } from "@codemirror/language";

/**
 * Syntax highlighting — GitHub Light.
 * Colors only, no font-size or font-weight changes.
 * Edit mode = raw monospace text with syntax coloring.
 */
const lightMarkdownStyle = HighlightStyle.define([
  // Headings — blue accent
  { tag: tags.heading1, color: "#0550ae" },
  { tag: tags.heading2, color: "#0550ae" },
  { tag: tags.heading3, color: "#0550ae" },
  { tag: tags.heading4, color: "#0550ae" },
  { tag: tags.heading5, color: "#0550ae" },
  { tag: tags.heading6, color: "#6e7781" },
  { tag: tags.heading, color: "#0550ae" },

  // Emphasis — color only, no style changes
  { tag: tags.emphasis, color: "#24292f" },
  { tag: tags.strong, color: "#24292f" },
  { tag: tags.strikethrough, color: "#6e7781" },

  // Links
  { tag: tags.link, color: "#0550ae" },
  { tag: tags.url, color: "#0a3069" },

  // Inline code
  { tag: tags.monospace, color: "#0550ae" },

  // Markdown syntax chars (#, **, *, ```, >, -)
  { tag: tags.processingInstruction, color: "#6e7781" },
  { tag: tags.meta, color: "#6e7781" },

  // Blockquotes
  { tag: tags.quote, color: "#116329" },

  // Lists
  { tag: tags.list, color: "#953800" },

  // Horizontal rule
  { tag: tags.contentSeparator, color: "#0550ae" },

  // Code syntax highlighting
  { tag: tags.keyword, color: "#cf222e" },
  { tag: tags.string, color: "#0a3069" },
  { tag: tags.comment, color: "#6e7781", fontStyle: "italic" },
  { tag: tags.number, color: "#0550ae" },
  { tag: tags.function(tags.variableName), color: "#8250df" },
  { tag: tags.definition(tags.variableName), color: "#8250df" },
  { tag: tags.typeName, color: "#953800" },
  { tag: tags.bool, color: "#0550ae" },
  { tag: tags.operator, color: "#24292f" },
  { tag: tags.className, color: "#953800" },
  { tag: tags.propertyName, color: "#24292f" },
  { tag: tags.attributeName, color: "#953800" },
  { tag: tags.attributeValue, color: "#0a3069" },
  { tag: tags.regexp, color: "#0a3069" },
  { tag: tags.tagName, color: "#116329" },
  { tag: tags.labelName, color: "#24292f" },
]);

/**
 * Syntax highlighting — GitHub Dark.
 */
const darkMarkdownStyle = HighlightStyle.define([
  // Headings
  { tag: tags.heading1, color: "#79c0ff" },
  { tag: tags.heading2, color: "#79c0ff" },
  { tag: tags.heading3, color: "#79c0ff" },
  { tag: tags.heading4, color: "#79c0ff" },
  { tag: tags.heading5, color: "#79c0ff" },
  { tag: tags.heading6, color: "#8b949e" },
  { tag: tags.heading, color: "#79c0ff" },

  // Emphasis
  { tag: tags.emphasis, color: "#c9d1d9" },
  { tag: tags.strong, color: "#c9d1d9" },
  { tag: tags.strikethrough, color: "#8b949e" },

  // Links
  { tag: tags.link, color: "#79c0ff" },
  { tag: tags.url, color: "#a5d6ff" },

  // Inline code
  { tag: tags.monospace, color: "#79c0ff" },

  // Markdown syntax chars
  { tag: tags.processingInstruction, color: "#8b949e" },
  { tag: tags.meta, color: "#8b949e" },

  // Blockquotes
  { tag: tags.quote, color: "#7ee787" },

  // Lists
  { tag: tags.list, color: "#ffa657" },

  // Horizontal rule
  { tag: tags.contentSeparator, color: "#79c0ff" },

  // Code syntax highlighting
  { tag: tags.keyword, color: "#ff7b72" },
  { tag: tags.string, color: "#a5d6ff" },
  { tag: tags.comment, color: "#8b949e", fontStyle: "italic" },
  { tag: tags.number, color: "#79c0ff" },
  { tag: tags.function(tags.variableName), color: "#d2a8ff" },
  { tag: tags.definition(tags.variableName), color: "#d2a8ff" },
  { tag: tags.typeName, color: "#ffa657" },
  { tag: tags.bool, color: "#79c0ff" },
  { tag: tags.operator, color: "#c9d1d9" },
  { tag: tags.className, color: "#ffa657" },
  { tag: tags.propertyName, color: "#c9d1d9" },
  { tag: tags.attributeName, color: "#ffa657" },
  { tag: tags.attributeValue, color: "#a5d6ff" },
  { tag: tags.regexp, color: "#a5d6ff" },
  { tag: tags.tagName, color: "#7ee787" },
  { tag: tags.labelName, color: "#c9d1d9" },
]);

export { lightMarkdownStyle, darkMarkdownStyle };

/**
 * ViewPlugin that adds CSS classes to code block and blockquote lines
 * for background/border styling via the theme.
 */
export const headingLineClasses = ViewPlugin.fromClass(
  class {
    decorations: DecorationSet;
    constructor(view: EditorView) {
      this.decorations = buildLineDecorations(view);
    }
    update(update: { docChanged: boolean; viewportChanged: boolean; view: EditorView }) {
      if (update.docChanged || update.viewportChanged) {
        this.decorations = buildLineDecorations(update.view);
      }
    }
  },
  { decorations: (v) => v.decorations },
);

function buildLineDecorations(view: EditorView): DecorationSet {
  const decorations: { from: number; decoration: Decoration }[] = [];

  for (const { from, to } of view.visibleRanges) {
    syntaxTree(view.state).iterate({
      from,
      to,
      enter(node) {
        if (node.name === "FencedCode" || node.name === "CodeBlock") {
          const startLine = view.state.doc.lineAt(node.from);
          const endLine = view.state.doc.lineAt(node.to);
          for (let i = startLine.number; i <= endLine.number; i++) {
            const codeLine = view.state.doc.line(i);
            decorations.push({ from: codeLine.from, decoration: Decoration.line({ class: "cm-code-block" }) });
          }
        } else if (node.name === "Blockquote") {
          const startLine = view.state.doc.lineAt(node.from);
          const endLine = view.state.doc.lineAt(node.to);
          for (let i = startLine.number; i <= endLine.number; i++) {
            const quoteLine = view.state.doc.line(i);
            decorations.push({ from: quoteLine.from, decoration: Decoration.line({ class: "cm-blockquote" }) });
          }
        }
      },
    });
  }

  decorations.sort((a, b) => a.from - b.from);
  return Decoration.set(decorations.map((d) => d.decoration.range(d.from)));
}
