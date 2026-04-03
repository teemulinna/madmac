import { keymap, EditorView, ViewPlugin, ViewUpdate } from "@codemirror/view";
import { Extension } from "@codemirror/state";
import {
  fluidModeState,
  toggleBlockEditing,
  addBlockEditingEffect,
  clearAllEditing,
  findBlockAt,
} from "./state";
import { fluidDecorationPlugin, fluidModeTheme } from "./decorations";
import { fluidTransitionPlugin } from "./transitions";

/**
 * ViewPlugin that handles click events to toggle block editing.
 *
 * - Regular click: clears all editing, toggles the clicked block
 * - Cmd+click (Meta): adds the clicked block to the editing set
 * - Click on empty area: clears all editing
 */
const clickHandler = ViewPlugin.fromClass(
  class {
    constructor(readonly view: EditorView) {}

    update(_update: ViewUpdate) {
      // No-op — event handling is done via DOM events below
    }
  },
  {
    eventHandlers: {
      mousedown(event: MouseEvent, view: EditorView) {
        const pos = view.posAtCoords({ x: event.clientX, y: event.clientY });
        if (pos === null) return false;

        const block = findBlockAt(view.state, pos);
        if (!block) {
          // Clicked outside any block — clear all editing
          clearAllEditing(view);
          return false;
        }

        const blockFrom = block.from;

        if (event.metaKey) {
          // Cmd+click: add this block to editing set (multi-block)
          view.dispatch({
            effects: addBlockEditingEffect.of(blockFrom),
          });
        } else {
          // Regular click: clear others, toggle this block
          const currentEditing = view.state.field(fluidModeState, false);
          if (currentEditing && currentEditing.has(blockFrom)) {
            // Already editing — let CM6 handle cursor placement
            return false;
          }

          clearAllEditing(view);
          toggleBlockEditing(view, blockFrom);
        }

        return false; // Don't prevent default — let CM6 handle cursor
      },
    },
  },
);

/**
 * Keymap for Fluid Mode.
 * - Escape: clear all editing blocks (return to rendered state)
 */
const fluidKeymap = keymap.of([
  {
    key: "Escape",
    run(view) {
      const editing = view.state.field(fluidModeState, false);
      if (editing && editing.size > 0) {
        clearAllEditing(view);
        return true;
      }
      return false;
    },
  },
]);

/**
 * Input handler for markdown auto-pairing.
 * Detects "**" typed in sequence and inserts closing "**".
 */
const autoPairHandler = EditorView.inputHandler.of(
  (view, from, to, text) => {
    // Detect if the user just typed "*" after an existing "*"
    if (text === "*" && from === to && from > 0) {
      const before = view.state.doc.sliceString(from - 1, from);
      if (before === "*") {
        // User typed "**" — insert closing "**" and place cursor between
        view.dispatch({
          changes: { from, to, insert: "*" + "**" },
          selection: { anchor: from + 1 },
        });
        return true;
      }
    }
    return false;
  },
);

/**
 * The main Fluid Mode extension.
 * Returns all sub-extensions needed for Fluid Mode editing:
 * - State field for tracking editing blocks
 * - Decoration plugin for hiding/showing syntax
 * - Transition plugin for animated morphing
 * - Click handler for toggling block editing
 * - Escape key binding for clearing editing
 * - Auto-pair handler for markdown syntax
 * - Theme styles for rendered content
 */
export function fluidMode(): Extension {
  return [
    fluidModeState,
    fluidDecorationPlugin,
    fluidTransitionPlugin,
    clickHandler,
    fluidKeymap,
    autoPairHandler,
    fluidModeTheme,
  ];
}

// Re-export key utilities for external use
export {
  fluidModeState,
  getEditingBlocks,
  isBlockEditing,
  toggleBlockEditing,
  clearAllEditing,
  findBlockAt,
  getBlocksInRange,
  toggleBlockEffect,
  clearAllEditingEffect,
  addBlockEditingEffect,
} from "./state";
export { fluidDecorationPlugin, fluidModeTheme } from "./decorations";
export { fluidTransitionPlugin } from "./transitions";
