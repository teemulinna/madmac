// Agion brand preset for MadMac PDF export
// Based on Agion platform brand guidelines

#let brand-primary = rgb("#1a1a2e")
#let brand-accent = rgb("#4472C4")
#let brand-light = rgb("#f0f4f8")
#let brand-muted = rgb("#6b7280")

#set document(author: "MadMac")
#set page(
  paper: "a4",
  margin: 2cm,
  header: align(right, text(8pt, fill: brand-muted)[MadMac]),
  footer: align(center, text(8pt, fill: brand-muted)[#counter(page).display("1 / 1", both: true)]),
)

#set text(
  font: "Helvetica Neue",
  size: 10pt,
  fill: brand-primary,
)

#set par(justify: true, leading: 0.65em)
#set heading(numbering: "1.1")

#show heading.where(level: 1): it => {
  v(0.5cm)
  text(18pt, weight: "bold", fill: brand-primary, it)
  v(0.1cm)
  line(length: 100%, stroke: 2pt + brand-accent)
  v(0.4cm)
}

#show heading.where(level: 2): it => {
  v(0.4cm)
  text(14pt, weight: "bold", fill: brand-accent, it)
  v(0.2cm)
}

#show heading.where(level: 3): it => {
  v(0.3cm)
  text(12pt, weight: "semibold", fill: brand-primary, it)
  v(0.1cm)
}

#show link: it => text(fill: brand-accent, it)

#show raw.where(block: true): it => {
  block(
    width: 100%,
    fill: brand-light,
    inset: 10pt,
    radius: 4pt,
    it,
  )
}
