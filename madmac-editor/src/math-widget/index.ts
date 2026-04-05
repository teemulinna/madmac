import {
  Decoration,
  DecorationSet,
  EditorView,
} from "@codemirror/view";
import { EditorState, Extension, Range, StateField } from "@codemirror/state";
import { KaTeXWidget } from "./katex-widget";

// KaTeX CSS is injected via rollup banner (katex.min.css inlined in the bundle).
// No runtime CSS injection needed.

/**
 * Build math decorations by scanning the document for $...$ and $$...$$ patterns.
 */
function buildMathDecorations(state: EditorState): DecorationSet {
  const decorations: Range<Decoration>[] = [];
  const text = state.doc.toString();

  // Match display math $$...$$ first (greedy on the delimiters)
  const displayRegex = /\$\$([\s\S]+?)\$\$/g;

  for (const m of text.matchAll(displayRegex)) {
    const from = m.index!;
    const to = from + m[0].length;
    const tex = m[1].trim();
    if (tex.length > 0) {
      decorations.push(
        Decoration.replace({
          widget: new KaTeXWidget(tex, true),
          block: true,
        }).range(from, to),
      );
    }
  }

  // Match inline math $...$ (but not $$)
  const inlineRegex = /(?<!\$)\$(?!\$)(.+?)(?<!\$)\$(?!\$)/g;

  for (const m of text.matchAll(inlineRegex)) {
    const from = m.index!;
    const to = from + m[0].length;
    const tex = m[1].trim();
    if (tex.length > 0) {
      // Skip if this range overlaps with any display math decoration
      const overlaps = decorations.some(
        (d) => from < d.to && to > d.from,
      );
      if (!overlaps) {
        decorations.push(
          Decoration.replace({
            widget: new KaTeXWidget(tex, false),
          }).range(from, to),
        );
      }
    }
  }

  // Sort by position
  decorations.sort((a, b) => a.from - b.from || a.to - b.to);

  return Decoration.set(decorations, true);
}

/**
 * StateField that provides math decorations.
 * Using a StateField (not ViewPlugin) because display math $$...$$ can span
 * multiple lines, and CM6 forbids multi-line replace decorations in ViewPlugins.
 */
const mathField = StateField.define<DecorationSet>({
  create(state) {
    return buildMathDecorations(state);
  },
  update(decos, tr) {
    if (tr.docChanged) {
      return buildMathDecorations(tr.state);
    }
    return decos;
  },
  provide(field) {
    return EditorView.decorations.from(field);
  },
});

/**
 * The math rendering extension for CodeMirror 6.
 */
export function mathExtension(): Extension {
  return [mathField];
}
