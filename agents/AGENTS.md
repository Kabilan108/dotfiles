# agents notes

- Never capture wl-copy's stdout or stderr in `skills/niri-computer-use/scripts/acu`; send both to /dev/null as `clipboard_restore` does. wl-copy forks a daemon that keeps serving the clipboard and inherits those pipes, so a caller that captures them waits for an EOF that comes only when the daemon exits.
- Keep `cleanAnsi` in `opencode/tool/jupyter.ts` building its pattern from String.fromCharCode(0x1b) and new RegExp. Biome and similar TypeScript linters flag a control character such as ESC inside a regular expression literal.
- Keep every selector of the injected stylesheet in `skills/html-communication/scripts/diagrams.mts` inside :where(). That gives the rules zero specificity, so a page rule that sets a --pele-* variable on .pele-diagram wins without !important.
- Keep every `[compat.*]` cell off in `grok/config.toml`, and keep Claude's enabled plugins in its `[plugins] disabled` list. Grok is only an X search delegate, and by default it loads Claude's CLAUDE.md, rules, skills, MCP servers, hooks and plugins; the plugins follow Claude's `enabledPlugins` regardless of the compat cells.
- Name the `x_*` tools in `grok/rules/x-search.md` as built in and say to call them first. When the rule mentioned MCP X tools without that, Grok decided its X tools were an unconnected MCP server and fell back to web scrapes.
- Filter Grok's headless tools with `--disallowed-tools`. Any `--tools` allowlist drops the `x_*` tools: they have no tool ID it accepts.
