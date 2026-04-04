import { WidgetType } from "@codemirror/view";

// Mermaid is loaded at runtime via the pre-built UMD bundle.
// We access it through the global `mermaid` variable.
declare const mermaid: {
  initialize: (config: Record<string, unknown>) => void;
  render: (id: string, text: string) => Promise<{ svg: string }>;
};

let mermaidInitialized = false;
let renderCounter = 0;

function ensureMermaidInit(): void {
  if (mermaidInitialized) return;
  if (typeof mermaid === "undefined") return;
  mermaidInitialized = true;
  mermaid.initialize({
    startOnLoad: false,
    theme: "neutral",
    securityLevel: "loose",
  });
}

/**
 * Widget that renders a mermaid diagram to SVG.
 * Since mermaid.render() is async, we show a placeholder first
 * and replace it once rendering completes.
 */
export class MermaidWidget extends WidgetType {
  constructor(readonly code: string) {
    super();
  }

  toDOM(): HTMLElement {
    const container = document.createElement("div");
    container.className = "cm-mermaid-diagram";
    container.style.minHeight = "40px";

    ensureMermaidInit();

    if (typeof mermaid === "undefined") {
      container.textContent = this.code;
      return container;
    }

    const id = `mermaid-${++renderCounter}`;

    // Render asynchronously
    mermaid
      .render(id, this.code)
      .then(({ svg }) => {
        // Mermaid produces well-formed SVG. Parse it safely via DOMParser.
        const parser = new DOMParser();
        const svgDoc = parser.parseFromString(svg, "image/svg+xml");
        const svgEl = svgDoc.documentElement;
        container.textContent = "";
        container.appendChild(document.importNode(svgEl, true));
      })
      .catch(() => {
        // On error, show the raw code as fallback (no crash)
        container.textContent = this.code;
        container.style.whiteSpace = "pre";
        container.style.fontFamily = "monospace";
        container.style.fontSize = "12px";
        container.style.color = "#888";
      });

    return container;
  }

  eq(other: MermaidWidget): boolean {
    return this.code === other.code;
  }

  ignoreEvent(): boolean {
    return false;
  }
}
