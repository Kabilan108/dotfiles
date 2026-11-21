# agents notes

- Never capture wl-copy's stdout or stderr in `skills/niri-computer-use/scripts/acu`; send both to /dev/null as `clipboard_restore` does. wl-copy forks a daemon that keeps serving the clipboard and inherits those pipes, so a caller that captures them waits for an EOF that comes only when the daemon exits.
- Keep `cleanAnsi` in `opencode/tool/jupyter.ts` building its pattern from String.fromCharCode(0x1b) and new RegExp. Biome and similar TypeScript linters flag a control character such as ESC inside a regular expression literal.
- Keep every selector of the injected stylesheet in `skills/html-communication/scripts/diagrams.mts` inside :where(). That gives the rules zero specificity, so a page rule that sets a --pele-* variable on .pele-diagram wins without !important.
