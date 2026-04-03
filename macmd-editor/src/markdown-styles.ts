import { HighlightStyle, syntaxHighlighting } from "@codemirror/language";
import { tags } from "@lezer/highlight";
import { Extension } from "@codemirror/state";
import { ViewPlugin, DecorationSet, Decoration, EditorView } from "@codemirror/view";
import { syntaxTree } from "@codemirror/language";

/**
 * Syntax highlighting styles for markdown content.
 * Maps lezer-markdown tags to visual CSS styles for a beautiful reading experience.
 */

const lightMarkdownStyle = HighlightStyle.define([
  // Headings — styled large and bold via tag-based highlighting
  { tag: tags.heading1, fontSize: "2em", fontWeight: "700", lineHeight: "1.2", letterSpacing: "-0.02em" },
  { tag: tags.heading2, fontSize: "1.5em", fontWeight: "600", lineHeight: "1.3", letterSpacing: "-0.01em" },
  { tag: tags.heading3, fontSize: "1.25em", fontWeight: "600", lineHeight: "1.4" },
  { tag: tags.heading4, fontSize: "1.125em", fontWeight: "600", lineHeight: "1.4" },
  { tag: tags.heading5, fontSize: "1.0625em", fontWeight: "600", lineHeight: "1.5" },
  { tag: tags.heading6, fontSize: "1em", fontWeight: "600", lineHeight: "1.5", color: "#6e6e73" },

  // Emphasis
  { tag: tags.emphasis, fontStyle: "italic" },
  { tag: tags.strong, fontWeight: "700" },
  { tag: tags.strikethrough, textDecoration: "line-through", color: "#86868b" },

  // Links
  { tag: tags.link, color: "#007aff", textDecoration: "underline" },
  { tag: tags.url, color: "#007aff" },

  // Inline code
  {
    tag: tags.monospace,
    fontFamily: "'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace",
    fontSize: "0.9em",
    backgroundColor: "#f5f5f7",
    borderRadius: "3px",
  },

  // Code block / fenced code content
  {
    tag: tags.content,
    // default content — no special style
  },

  // Block-level markers
  { tag: tags.heading, fontWeight: "600" },
  { tag: tags.quote, color: "#6e6e73", fontStyle: "italic" },
  { tag: tags.list, color: "#1d1d1f" },

  // Markdown syntax characters (hash marks, asterisks, etc.)
  { tag: tags.processingInstruction, color: "#86868b" },
  { tag: tags.meta, color: "#86868b" },

  // Horizontal rule
  { tag: tags.contentSeparator, color: "#d1d1d6" },

  // Code block language-specific tokens (when code highlighting loads)
  { tag: tags.keyword, color: "#ad3da4" },
  { tag: tags.string, color: "#d12f1b" },
  { tag: tags.comment, color: "#8e8e93", fontStyle: "italic" },
  { tag: tags.number, color: "#272ad8" },
  { tag: tags.function(tags.variableName), color: "#4b21b0" },
  { tag: tags.definition(tags.variableName), color: "#3900a0" },
  { tag: tags.typeName, color: "#0b4f79" },
  { tag: tags.bool, color: "#ad3da4" },
  { tag: tags.operator, color: "#1d1d1f" },
  { tag: tags.className, color: "#3900a0" },
  { tag: tags.propertyName, color: "#1d1d1f" },
  { tag: tags.attributeName, color: "#836c28" },
  { tag: tags.attributeValue, color: "#d12f1b" },
  { tag: tags.regexp, color: "#d12f1b" },
  { tag: tags.tagName, color: "#ad3da4" },
  { tag: tags.labelName, color: "#1d1d1f" },
]);

const darkMarkdownStyle = HighlightStyle.define([
  // Headings
  { tag: tags.heading1, fontSize: "2em", fontWeight: "700", lineHeight: "1.2", letterSpacing: "-0.02em" },
  { tag: tags.heading2, fontSize: "1.5em", fontWeight: "600", lineHeight: "1.3", letterSpacing: "-0.01em" },
  { tag: tags.heading3, fontSize: "1.25em", fontWeight: "600", lineHeight: "1.4" },
  { tag: tags.heading4, fontSize: "1.125em", fontWeight: "600", lineHeight: "1.4" },
  { tag: tags.heading5, fontSize: "1.0625em", fontWeight: "600", lineHeight: "1.5" },
  { tag: tags.heading6, fontSize: "1em", fontWeight: "600", lineHeight: "1.5", color: "#98989d" },

  // Emphasis
  { tag: tags.emphasis, fontStyle: "italic" },
  { tag: tags.strong, fontWeight: "700" },
  { tag: tags.strikethrough, textDecoration: "line-through", color: "#98989d" },

  // Links
  { tag: tags.link, color: "#0a84ff", textDecoration: "underline" },
  { tag: tags.url, color: "#0a84ff" },

  // Inline code
  {
    tag: tags.monospace,
    fontFamily: "'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace",
    fontSize: "0.9em",
    backgroundColor: "#2c2c2e",
    borderRadius: "3px",
  },

  // Block-level markers
  { tag: tags.heading, fontWeight: "600" },
  { tag: tags.quote, color: "#98989d", fontStyle: "italic" },
  { tag: tags.list, color: "#e5e5e7" },

  // Markdown syntax characters
  { tag: tags.processingInstruction, color: "#636366" },
  { tag: tags.meta, color: "#636366" },

  // Horizontal rule
  { tag: tags.contentSeparator, color: "#48484a" },

  // Code block language-specific tokens
  { tag: tags.keyword, color: "#ff7ab2" },
  { tag: tags.string, color: "#ff8170" },
  { tag: tags.comment, color: "#7f8c8d", fontStyle: "italic" },
  { tag: tags.number, color: "#d9c97c" },
  { tag: tags.function(tags.variableName), color: "#b281eb" },
  { tag: tags.definition(tags.variableName), color: "#b281eb" },
  { tag: tags.typeName, color: "#6bdfff" },
  { tag: tags.bool, color: "#ff7ab2" },
  { tag: tags.operator, color: "#e5e5e7" },
  { tag: tags.className, color: "#dabaff" },
  { tag: tags.propertyName, color: "#e5e5e7" },
  { tag: tags.attributeName, color: "#d9c97c" },
  { tag: tags.attributeValue, color: "#ff8170" },
  { tag: tags.regexp, color: "#ff8170" },
  { tag: tags.tagName, color: "#ff7ab2" },
  { tag: tags.labelName, color: "#e5e5e7" },
]);

/**
 * Returns the syntax highlighting extension for the given theme variant.
 */
export function markdownHighlighting(variant: "light" | "dark" = "light"): Extension {
  return syntaxHighlighting(
    variant === "dark" ? darkMarkdownStyle : lightMarkdownStyle,
  );
}

/**
 * Both light and dark styles available for compartment switching.
 */
export { lightMarkdownStyle, darkMarkdownStyle };

/**
 * ViewPlugin that adds CSS classes to heading lines so the theme can
 * style them via `.cm-heading-1` etc.  This bridges lezer syntax tree
 * node types to DOM classes that EditorView.theme() rules can target.
 */
export const headingLineClasses = ViewPlugin.fromClass(
  class {
    decorations: DecorationSet;
    constructor(view: EditorView) {
      this.decorations = buildHeadingDecorations(view);
    }
    update(update: { docChanged: boolean; viewportChanged: boolean; view: EditorView }) {
      if (update.docChanged || update.viewportChanged) {
        this.decorations = buildHeadingDecorations(update.view);
      }
    }
  },
  { decorations: (v) => v.decorations },
);

function buildHeadingDecorations(view: EditorView): DecorationSet {
  const decorations: { from: number; to: number; decoration: Decoration }[] = [];

  for (const { from, to } of view.visibleRanges) {
    syntaxTree(view.state).iterate({
      from,
      to,
      enter(node) {
        if (node.name === "ATXHeading1" || node.name === "SetextHeading1") {
          const line = view.state.doc.lineAt(node.from);
          decorations.push({ from: line.from, to: line.from, decoration: Decoration.line({ class: "cm-heading-1" }) });
        } else if (node.name === "ATXHeading2" || node.name === "SetextHeading2") {
          const line = view.state.doc.lineAt(node.from);
          decorations.push({ from: line.from, to: line.from, decoration: Decoration.line({ class: "cm-heading-2" }) });
        } else if (node.name === "ATXHeading3") {
          const line = view.state.doc.lineAt(node.from);
          decorations.push({ from: line.from, to: line.from, decoration: Decoration.line({ class: "cm-heading-3" }) });
        } else if (node.name === "ATXHeading4") {
          const line = view.state.doc.lineAt(node.from);
          decorations.push({ from: line.from, to: line.from, decoration: Decoration.line({ class: "cm-heading-4" }) });
        } else if (node.name === "ATXHeading5") {
          const line = view.state.doc.lineAt(node.from);
          decorations.push({ from: line.from, to: line.from, decoration: Decoration.line({ class: "cm-heading-5" }) });
        } else if (node.name === "ATXHeading6") {
          const line = view.state.doc.lineAt(node.from);
          decorations.push({ from: line.from, to: line.from, decoration: Decoration.line({ class: "cm-heading-6" }) });
        } else if (node.name === "FencedCode" || node.name === "CodeBlock") {
          // Add code-block class to each line in a fenced code block
          const startLine = view.state.doc.lineAt(node.from);
          const endLine = view.state.doc.lineAt(node.to);
          for (let i = startLine.number; i <= endLine.number; i++) {
            const line = view.state.doc.line(i);
            decorations.push({ from: line.from, to: line.from, decoration: Decoration.line({ class: "cm-code-block" }) });
          }
        } else if (node.name === "Blockquote") {
          const startLine = view.state.doc.lineAt(node.from);
          const endLine = view.state.doc.lineAt(node.to);
          for (let i = startLine.number; i <= endLine.number; i++) {
            const line = view.state.doc.line(i);
            decorations.push({ from: line.from, to: line.from, decoration: Decoration.line({ class: "cm-blockquote" }) });
          }
        }
      },
    });
  }

  // Sort and de-duplicate by position
  decorations.sort((a, b) => a.from - b.from);
  return Decoration.set(decorations.map((d) => d.decoration.range(d.from)));
}
