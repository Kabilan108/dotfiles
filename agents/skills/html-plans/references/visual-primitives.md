# Visual primitives

Use the smallest visual that clarifies the relationship.

- Real HTML tables for comparisons, audits, APIs, and matrices. Use sticky headers and an overflow wrapper.
- Mermaid for flow, sequence, state, schema, and topology. Complex diagrams need zoom/pan or a simple overview followed by detail cards.
- CSS timelines for milestones and incident chronology.
- Cards for modules with rich descriptions; vary visual weight so summaries dominate reference material.
- Code blocks require filenames, preserved whitespace, wrapping or horizontal scrolling, and focused excerpts.
- Use `<details>` for evidence or secondary depth, not primary conclusions.
- At four substantial sections, add stable anchors and responsive navigation.

Define a small token palette (`--bg`, `--surface`, `--line`, `--text`, `--muted`, accents). Avoid generic neon gradients, glowing cards, emoji section headers, and uniform card grids. Support narrow screens, print, and reduced motion. External fonts and chart libraries require an explicit reason; inline SVG is preferred.
