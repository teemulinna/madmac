import {
  Decoration,
  DecorationSet,
  EditorView,
  ViewPlugin,
  ViewUpdate,
  WidgetType,
} from "@codemirror/view";
import { Range } from "@codemirror/state";
import { syntaxTree } from "@codemirror/language";
import { fluidModeState, BLOCK_NODE_NAMES } from "./state";

/**
 * Widget that renders an <img> element for image syntax in rendered mode.
 */
class ImageWidget extends WidgetType {
  constructor(
    readonly alt: string,
    readonly src: string,
  ) {
    super();
  }

  toDOM(): HTMLElement {
    const img = document.createElement("img");
    img.alt = this.alt;
    img.src = this.src;
    img.style.maxWidth = "100%";
    img.style.borderRadius = "4px";
    img.onerror = () => {
      img.style.display = "none";
      const placeholder = document.createElement("span");
      placeholder.className = "cm-fluid-image-missing";
      placeholder.textContent = `[Image not found: ${this.alt}]`;
      placeholder.style.color = "#86868b";
      placeholder.style.fontStyle = "italic";
      img.parentElement?.replaceChild(placeholder, img);
    };
    return img;
  }

  eq(other: ImageWidget): boolean {
    return this.alt === other.alt && this.src === other.src;
  }
}

/**
 * Find the enclosing block-level node for a given position.
 * Returns the block's from position, or -1 if not found.
 */
function findEnclosingBlockFrom(
  _state: { doc: { length: number } },
  tree: ReturnType<typeof syntaxTree>,
  pos: number,
): number {
  let cursor = tree.resolve(pos, 1);
  while (cursor) {
    if (BLOCK_NODE_NAMES.has(cursor.name)) {
      return cursor.from;
    }
    if (!cursor.parent) break;
    cursor = cursor.parent;
  }
  cursor = tree.resolve(pos, -1);
  while (cursor) {
    if (BLOCK_NODE_NAMES.has(cursor.name)) {
      return cursor.from;
    }
    if (!cursor.parent) break;
    cursor = cursor.parent;
  }
  return -1;
}

/**
 * CSS classes applied by Fluid Mode decorations.
 */
const fluidBold = Decoration.mark({ class: "cm-fluid-bold" });
const fluidItalic = Decoration.mark({ class: "cm-fluid-italic" });
const fluidStrikethrough = Decoration.mark({ class: "cm-fluid-strikethrough" });
const fluidLinkText = Decoration.mark({ class: "cm-fluid-link-text" });
const fluidHeading1 = Decoration.mark({ class: "cm-fluid-h1" });
const fluidHeading2 = Decoration.mark({ class: "cm-fluid-h2" });
const fluidHeading3 = Decoration.mark({ class: "cm-fluid-h3" });
const fluidHeading4 = Decoration.mark({ class: "cm-fluid-h4" });
const fluidHeading5 = Decoration.mark({ class: "cm-fluid-h5" });
const fluidHeading6 = Decoration.mark({ class: "cm-fluid-h6" });

const headingMarkMap: Record<string, Decoration> = {
  ATXHeading1: fluidHeading1,
  ATXHeading2: fluidHeading2,
  ATXHeading3: fluidHeading3,
  ATXHeading4: fluidHeading4,
  ATXHeading5: fluidHeading5,
  ATXHeading6: fluidHeading6,
};

/**
 * Build decorations for Fluid Mode.
 *
 * For blocks NOT in the editing set, hide markdown syntax and apply styling.
 * For blocks IN the editing set, show raw markdown (no decorations applied).
 */
function buildFluidDecorations(view: EditorView): DecorationSet {
  const editingBlocks = view.state.field(fluidModeState, false) ?? new Set<number>();
  const decorations: Range<Decoration>[] = [];
  const tree = syntaxTree(view.state);

  for (const { from, to } of view.visibleRanges) {
    tree.iterate({
      from,
      to,
      enter(node) {
        // Find the enclosing block for this node
        const blockFrom = findEnclosingBlockFrom(view.state, tree, node.from);

        // If the enclosing block is being edited, skip all decorations
        if (blockFrom >= 0 && editingBlocks.has(blockFrom)) {
          return;
        }

        // -- ATX Headings: hide the "# " prefix, style the content --
        if (node.name.startsWith("ATXHeading")) {
          const headingMark = headingMarkMap[node.name];
          if (!headingMark) return;

          // Find HeaderMark children to hide them
          const headingNode = node.node;
          let headerMarkEnd = node.from;
          const child = headingNode.firstChild;
          if (child && child.name === "HeaderMark") {
            headerMarkEnd = child.to;
            // Hide the "# " (mark + following space)
            const hideEnd = Math.min(headerMarkEnd + 1, node.to);
            if (hideEnd > child.from) {
              decorations.push(
                Decoration.replace({}).range(child.from, hideEnd),
              );
            }
          }

          // Style the heading text content
          const textFrom = headerMarkEnd < node.to ? headerMarkEnd + 1 : headerMarkEnd;
          const textTo = node.to;
          if (textTo > textFrom) {
            decorations.push(headingMark.range(Math.min(textFrom, node.to), textTo));
          }

          return false; // Don't descend further into heading children
        }

        // -- StrongEmphasis: hide ** markers, apply bold --
        if (node.name === "StrongEmphasis") {
          const innerFrom = node.from + 2; // skip opening **
          const innerTo = node.to - 2; // skip closing **
          if (innerTo > innerFrom) {
            // Hide opening markers
            decorations.push(
              Decoration.replace({}).range(node.from, innerFrom),
            );
            // Hide closing markers
            decorations.push(
              Decoration.replace({}).range(innerTo, node.to),
            );
            // Style the content as bold
            decorations.push(fluidBold.range(innerFrom, innerTo));
          }
          return false;
        }

        // -- Emphasis: hide * markers, apply italic --
        if (node.name === "Emphasis") {
          const innerFrom = node.from + 1; // skip opening *
          const innerTo = node.to - 1; // skip closing *
          if (innerTo > innerFrom) {
            // Hide opening marker
            decorations.push(
              Decoration.replace({}).range(node.from, innerFrom),
            );
            // Hide closing marker
            decorations.push(
              Decoration.replace({}).range(innerTo, node.to),
            );
            // Style the content as italic
            decorations.push(fluidItalic.range(innerFrom, innerTo));
          }
          return false;
        }

        // -- Links: hide [, ](url), show only link text --
        if (node.name === "Link") {
          const linkNode = node.node;
          // Find the LinkMark "[", the URL, and closing parts
          // Structure: [ LinkLabel ] ( URL )
          // Children: LinkMark "[" ... LinkMark "]" LinkMark "(" URL LinkMark ")"
          let labelStart = -1;
          let labelEnd = -1;
          const marks: { from: number; to: number }[] = [];

          let child = linkNode.firstChild;
          while (child) {
            if (child.name === "LinkMark") {
              marks.push({ from: child.from, to: child.to });
            }
            child = child.nextSibling;
          }

          // Typically marks are: [ ] ( )
          // We want to hide: "[" at start, "](url)" at end
          if (marks.length >= 2) {
            // Hide the opening "["
            decorations.push(
              Decoration.replace({}).range(marks[0].from, marks[0].to),
            );

            // The link text is between first mark end and second mark start
            labelStart = marks[0].to;
            labelEnd = marks[1].from;

            // Hide from "]" onwards to the end of the link node
            if (marks[1].from < node.to) {
              decorations.push(
                Decoration.replace({}).range(marks[1].from, node.to),
              );
            }

            // Style the link text
            if (labelEnd > labelStart) {
              decorations.push(fluidLinkText.range(labelStart, labelEnd));
            }
          }

          return false;
        }

        // -- Images: replace entire syntax with widget --
        if (node.name === "Image") {
          const text = view.state.doc.sliceString(node.from, node.to);
          const altMatch = text.match(/^!\[([^\]]*)\]/);
          const srcMatch = text.match(/\]\(([^)]*)\)/);
          const alt = altMatch ? altMatch[1] : "";
          const src = srcMatch ? srcMatch[1] : "";

          decorations.push(
            Decoration.replace({
              widget: new ImageWidget(alt, src),
            }).range(node.from, node.to),
          );
          return false;
        }

        // -- Strikethrough: hide ~~ markers --
        if (node.name === "Strikethrough") {
          const innerFrom = node.from + 2;
          const innerTo = node.to - 2;
          if (innerTo > innerFrom) {
            decorations.push(
              Decoration.replace({}).range(node.from, innerFrom),
            );
            decorations.push(
              Decoration.replace({}).range(innerTo, node.to),
            );
            decorations.push(fluidStrikethrough.range(innerFrom, innerTo));
          }
          return false;
        }
      },
    });
  }

  // Sort decorations by from position (required by RangeSetBuilder)
  decorations.sort((a, b) => a.from - b.from || a.to - b.to);

  // Deduplicate overlapping replace decorations — keep the first one.
  // This prevents CM6 from crashing on overlapping replacements.
  const filtered: Range<Decoration>[] = [];
  let lastReplaceTo = -1;
  for (const deco of decorations) {
    // Check if this is a replace decoration (has the replace flag)
    const spec = (deco.value as unknown as { replace?: boolean }).replace;
    if (spec !== undefined) {
      // This is a replace decoration
      if (deco.from < lastReplaceTo) {
        // Overlaps with a previous replace — skip
        continue;
      }
      lastReplaceTo = deco.to;
    }
    filtered.push(deco);
  }

  return Decoration.set(filtered, true);
}

/**
 * ViewPlugin that produces Fluid Mode decorations.
 * Rebuilds whenever the document, viewport, or editing set changes.
 */
export const fluidDecorationPlugin = ViewPlugin.fromClass(
  class {
    decorations: DecorationSet;

    constructor(view: EditorView) {
      this.decorations = buildFluidDecorations(view);
    }

    update(update: ViewUpdate) {
      if (
        update.docChanged ||
        update.viewportChanged ||
        update.startState.field(fluidModeState, false) !==
          update.state.field(fluidModeState, false)
      ) {
        this.decorations = buildFluidDecorations(update.view);
      }
    }
  },
  {
    decorations: (v) => v.decorations,
  },
);

/**
 * Base theme for Fluid Mode rendered styles.
 */
export const fluidModeTheme = EditorView.baseTheme({
  ".cm-fluid-bold": {
    fontWeight: "700",
  },
  ".cm-fluid-italic": {
    fontStyle: "italic",
  },
  ".cm-fluid-strikethrough": {
    textDecoration: "line-through",
  },
  ".cm-fluid-link-text": {
    color: "#007aff",
    textDecoration: "underline",
    cursor: "pointer",
  },
  ".cm-fluid-h1": {
    fontSize: "2em",
    fontWeight: "700",
    lineHeight: "1.2",
    letterSpacing: "-0.02em",
  },
  ".cm-fluid-h2": {
    fontSize: "1.5em",
    fontWeight: "600",
    lineHeight: "1.3",
    letterSpacing: "-0.01em",
  },
  ".cm-fluid-h3": {
    fontSize: "1.25em",
    fontWeight: "600",
    lineHeight: "1.4",
  },
  ".cm-fluid-h4": {
    fontSize: "1.125em",
    fontWeight: "600",
    lineHeight: "1.4",
  },
  ".cm-fluid-h5": {
    fontSize: "1.0625em",
    fontWeight: "600",
    lineHeight: "1.5",
  },
  ".cm-fluid-h6": {
    fontSize: "1em",
    fontWeight: "600",
    lineHeight: "1.5",
  },
  ".cm-fluid-image-missing": {
    color: "#86868b",
    fontStyle: "italic",
    padding: "4px 8px",
    border: "1px dashed #d1d1d6",
    borderRadius: "4px",
    display: "inline-block",
  },
  // Transition classes
  ".cm-fluid-block": {
    transition: "height 200ms ease-out",
  },
  ".cm-fluid-block-entering": {
    opacity: "0",
  },
  ".cm-fluid-block-entered": {
    opacity: "1",
    transition: "opacity 150ms ease-in",
  },
});
