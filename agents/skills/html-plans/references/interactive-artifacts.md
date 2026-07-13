# Interactive artifacts

Interaction must shorten a real engineering feedback loop.

- Keep one state object. Every control updates state, preview, validation, and export together.
- Start with useful defaults. Add presets only when they represent coherent real choices.
- Show current state and validation errors without requiring an Apply button.
- Provide reset and keyboard operation.
- Export an actionable artifact: Markdown, JSON, diff, CSS, or natural-language prompt. Do not emit a raw value dump.
- Treat repository or user-provided text as untrusted. Prefer `textContent`; escape before `innerHTML`.
- Provide a deterministic static fallback for the important conclusions.

Skip interaction when filters, tabs, or animation merely decorate content.
