import { EditorView, ViewPlugin, ViewUpdate } from "@codemirror/view";
import { fluidModeState } from "./state";

/**
 * Transition ViewPlugin that animates blocks entering/exiting edit mode.
 *
 * When the editing set changes, this plugin identifies affected lines
 * and applies CSS transition classes for smooth height and opacity animation.
 *
 * The animation flow:
 * 1. Measure current height of affected lines
 * 2. Set explicit height to prevent layout jump
 * 3. Apply transition classes
 * 4. After transition completes (~200ms), remove explicit height
 */
export const fluidTransitionPlugin = ViewPlugin.fromClass(
  class {
    private previousEditing: Set<number>;

    constructor(view: EditorView) {
      this.previousEditing = new Set(
        view.state.field(fluidModeState, false) ?? [],
      );
    }

    update(update: ViewUpdate) {
      const currentEditing =
        update.state.field(fluidModeState, false) ?? new Set<number>();
      const prevEditing = this.previousEditing;

      // Detect blocks that entered or exited editing mode
      const entered: number[] = [];
      const exited: number[] = [];

      for (const pos of currentEditing) {
        if (!prevEditing.has(pos)) {
          entered.push(pos);
        }
      }
      for (const pos of prevEditing) {
        if (!currentEditing.has(pos)) {
          exited.push(pos);
        }
      }

      this.previousEditing = new Set(currentEditing);

      // Apply transition animations to affected blocks
      if (entered.length > 0 || exited.length > 0) {
        this.animateTransitions(update.view, entered, exited);
      }
    }

    private animateTransitions(
      view: EditorView,
      entered: number[],
      exited: number[],
    ) {
      // Use requestAnimationFrame to ensure DOM has updated
      requestAnimationFrame(() => {
        const allPositions = [...entered, ...exited];

        for (const pos of allPositions) {
          if (pos > view.state.doc.length) continue;

          try {
            const line = view.state.doc.lineAt(pos);
            const lineBlock = view.lineBlockAt(line.from);
            const dom = view.domAtPos(lineBlock.from);

            // Find the nearest .cm-line element
            let lineEl: HTMLElement | null = null;
            if (dom.node instanceof HTMLElement) {
              lineEl =
                dom.node.closest(".cm-line") ??
                dom.node.querySelector(".cm-line");
            } else if (dom.node.parentElement) {
              lineEl = dom.node.parentElement.closest(".cm-line");
            }

            if (!lineEl) continue;

            // Capture current height
            const currentHeight = lineEl.getBoundingClientRect().height;

            // Set explicit height to freeze layout
            lineEl.style.height = `${currentHeight}px`;
            lineEl.classList.add("cm-fluid-block");

            if (entered.includes(pos)) {
              lineEl.classList.add("cm-fluid-block-entering");
            }

            // Trigger reflow, then animate
            // eslint-disable-next-line @typescript-eslint/no-unused-expressions
            lineEl.offsetHeight;

            requestAnimationFrame(() => {
              if (!lineEl) return;
              lineEl.style.height = "";
              lineEl.classList.remove("cm-fluid-block-entering");
              lineEl.classList.add("cm-fluid-block-entered");

              // Clean up classes after transition completes
              setTimeout(() => {
                if (!lineEl) return;
                lineEl.classList.remove(
                  "cm-fluid-block",
                  "cm-fluid-block-entered",
                );
              }, 200);
            });
          } catch {
            // Position may no longer be valid — ignore
          }
        }
      });
    }

    destroy() {
      // No cleanup needed
    }
  },
);
