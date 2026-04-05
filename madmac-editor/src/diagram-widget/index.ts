import {
  Decoration,
  DecorationSet,
  EditorView,
} from "@codemirror/view";
import { EditorState, Extension, Range, StateField } from "@codemirror/state";
import { syntaxTree } from "@codemirror/language";
import { MermaidWidget } from "./mermaid-widget";
import { fluidModeState } from "../fluid-mode/state";

/**
 * Build decorations for mermaid code blocks.
 * Finds FencedCode nodes with "mermaid" language info and replaces them
 * with MermaidWidget decorations.
 *
 * If a block is currently being edited in fluid mode, skip it so the user
 * sees the raw markdown source.
 */
function buildMermaidDecorations(state: EditorState): DecorationSet {
  const decorations: Range<Decoration>[] = [];
  const tree = syntaxTree(state);
  const doc = state.doc;

  // Check which blocks are being edited in fluid mode
  const editingBlocks = state.field(fluidModeState, false) ?? new Set<number>();

  tree.iterate({
    enter(node) {
      if (node.name !== "FencedCode") return;

      // If this block is being edited, don't replace it with the widget
      if (editingBlocks.has(node.from)) return;

      // Get the full text of the fenced code block
      const fullText = doc.sliceString(node.from, node.to);

      // Check if the first line contains "mermaid" as the language
      const firstLineEnd = fullText.indexOf("\n");
      if (firstLineEnd === -1) return;
      const firstLine = fullText.substring(0, firstLineEnd).trim();
      if (!firstLine.match(/^```+\s*mermaid\s*$/)) return;

      // Extract the code content (between opening ``` and closing ```)
      const lastBacktickLine = fullText.lastIndexOf("```");
      if (lastBacktickLine <= firstLineEnd) return;

      const code = fullText
        .substring(firstLineEnd + 1, lastBacktickLine)
        .trim();

      if (code.length === 0) return;

      decorations.push(
        Decoration.replace({
          widget: new MermaidWidget(code),
          block: true,
        }).range(node.from, node.to),
      );
    },
  });

  decorations.sort((a, b) => a.from - b.from);
  return Decoration.set(decorations, true);
}

/**
 * StateField that provides mermaid decorations.
 * Using a StateField (not ViewPlugin) because the replace decorations
 * span multiple lines, which CM6 forbids for ViewPlugin decorations.
 */
const mermaidField = StateField.define<DecorationSet>({
  create(state) {
    return buildMermaidDecorations(state);
  },
  update(_decos, tr) {
    // Rebuild on doc changes or any effects (which include editing state changes)
    return buildMermaidDecorations(tr.state);
  },
  provide(field) {
    return EditorView.decorations.from(field);
  },
});

/**
 * The mermaid diagram rendering extension for CodeMirror 6.
 */
export function mermaidExtension(): Extension {
  return [mermaidField];
}
