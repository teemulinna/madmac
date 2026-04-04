// Minimal preset for MadMac PDF export
// Clean, no branding, optimized for readability

#set document(author: "MadMac")
#set page(
  paper: "a4",
  margin: 2.5cm,
  footer: align(center, text(9pt, fill: luma(150))[#counter(page).display()]),
)

#set text(
  font: "Helvetica Neue",
  size: 11pt,
  fill: luma(30),
)

#set par(justify: true, leading: 0.7em)

#show heading.where(level: 1): it => {
  v(0.6cm)
  text(20pt, weight: "bold", it)
  v(0.3cm)
}

#show heading.where(level: 2): it => {
  v(0.4cm)
  text(15pt, weight: "bold", it)
  v(0.2cm)
}

#show heading.where(level: 3): it => {
  v(0.3cm)
  text(12pt, weight: "semibold", it)
  v(0.1cm)
}

#show raw.where(block: true): it => {
  block(
    width: 100%,
    fill: luma(245),
    inset: 10pt,
    radius: 3pt,
    it,
  )
}
