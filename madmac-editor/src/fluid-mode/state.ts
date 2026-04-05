import { StateField, StateEffect, EditorState } from "@codemirror/state";
import { EditorView } from "@codemirror/view";
import { syntaxTree } from "@codemirror/language";
import type { SyntaxNode } from "@lezer/common";

/**
 * Block types recognized by Fluid Mode.
 * These map to lezer-markdown syntax tree node names.
 */
const BLOCK_NODE_NAMES = new Set([
  "ATXHeading1",
  "ATXHeading2",
  "ATXHeading3",
  "ATXHeading4",
  "ATXHeading5",
  "ATXHeading6",
  "SetextHeading1",
  "SetextHeading2",
  "Paragraph",
  "FencedCode",
  "CodeBlock",
  "Blockquote",
  "BulletList",
  "OrderedList",
  "HorizontalRule",
  "HTMLBlock",
  "Table",
]);

/**
 * Effect to toggle a block's editing state.
 * The number is the block's `from` position in the document.
 */
export const toggleBlockEffect = StateEffect.define<number>();

/**
 * Effect to clear all editing blocks.
 */
export const clearAllEditingEffect = StateEffect.define<void>();

/**
 * Effect to set a specific block as editing (used for Cmd+click to add).
 */
export const addBlockEditingEffect = StateEffect.define<number>();

/**
 * StateField tracking which block positions are currently in editing mode.
 * The Set contains the `from` position of each editing block.
 */
export const fluidModeState: StateField<Set<number>> = StateField.define<Set<number>>({
  create() {
    return new Set();
  },

  update(editingBlocks, tr) {
    let blocks = editingBlocks;

    // If the document changed, update positions.
    // Blocks whose positions shifted need to be remapped.
    if (tr.docChanged) {
      const newBlocks = new Set<number>();
      for (const pos of blocks) {
        const mapped = tr.changes.mapPos(pos, 1);
        // Only keep if it still maps to a valid position
        if (mapped >= 0 && mapped <= tr.newDoc.length) {
          newBlocks.add(mapped);
        }
      }
      blocks = newBlocks;
    }

    for (const effect of tr.effects) {
      if (effect.is(toggleBlockEffect)) {
        const newBlocks = new Set(blocks);
        if (newBlocks.has(effect.value)) {
          newBlocks.delete(effect.value);
        } else {
          newBlocks.add(effect.value);
        }
        blocks = newBlocks;
      } else if (effect.is(clearAllEditingEffect)) {
        blocks = new Set();
      } else if (effect.is(addBlockEditingEffect)) {
        if (!blocks.has(effect.value)) {
          const newBlocks = new Set(blocks);
          newBlocks.add(effect.value);
          blocks = newBlocks;
        }
      }
    }

    return blocks;
  },
});

/**
 * Get the set of block positions currently being edited.
 */
export function getEditingBlocks(state: EditorState): Set<number> {
  return state.field(fluidModeState, false) ?? new Set();
}

/**
 * Check if a specific block (by its from-position) is in editing mode.
 */
export function isBlockEditing(state: EditorState, blockPos: number): boolean {
  return getEditingBlocks(state).has(blockPos);
}

/**
 * Toggle a block between editing and rendered state.
 */
export function toggleBlockEditing(view: EditorView, blockPos: number): void {
  view.dispatch({
    effects: toggleBlockEffect.of(blockPos),
  });
}

/**
 * Clear all editing blocks, returning them to rendered state.
 */
export function clearAllEditing(view: EditorView): void {
  view.dispatch({
    effects: clearAllEditingEffect.of(undefined),
  });
}

/**
 * Find the enclosing block node for a given document position.
 * Returns the block node or null if not found.
 */
export function findBlockAt(state: EditorState, pos: number): SyntaxNode | null {
  const tree = syntaxTree(state);
  let cursor = tree.resolve(pos, 1);

  // Walk up the tree to find the nearest block-level node
  while (cursor) {
    if (BLOCK_NODE_NAMES.has(cursor.name)) {
      return cursor.node;
    }
    if (!cursor.parent) break;
    cursor = cursor.parent;
  }

  // Also try resolving from the left side
  cursor = tree.resolve(pos, -1);
  while (cursor) {
    if (BLOCK_NODE_NAMES.has(cursor.name)) {
      return cursor.node;
    }
    if (!cursor.parent) break;
    cursor = cursor.parent;
  }

  return null;
}

/**
 * Get all block nodes in the given range from the syntax tree.
 */
export function getBlocksInRange(
  state: EditorState,
  from: number,
  to: number,
): { name: string; from: number; to: number }[] {
  const tree = syntaxTree(state);
  const blocks: { name: string; from: number; to: number }[] = [];

  tree.iterate({
    from,
    to,
    enter(node) {
      if (BLOCK_NODE_NAMES.has(node.name)) {
        blocks.push({ name: node.name, from: node.from, to: node.to });
        return false; // Don't descend into block children (they're inline)
      }
    },
  });

  return blocks;
}

export { BLOCK_NODE_NAMES };
