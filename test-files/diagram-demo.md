# Diagram & Math Demo

## Mermaid Flowchart

```mermaid
graph TD
  A[User opens .md] --> B{Has diagrams?}
  B -->|Yes| C[Render SVG inline]
  B -->|No| D[Show rendered text]
  C --> E[Beautiful document]
  D --> E
```

## Inline Math

The equation $E = mc^2$ shows energy-mass equivalence.

Euler's identity: $e^{i\pi} + 1 = 0$

## Display Math

$$\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}$$

## Mermaid Sequence Diagram

```mermaid
sequenceDiagram
  participant U as User
  participant A as macmd App
  participant R as Rust Core
  U->>A: Opens .md file
  A->>R: Parse markdown
  R-->>A: HTML + SVG
  A-->>U: Rendered document
```

## Regular Text

This is just normal markdown with **bold** and *italic*.
