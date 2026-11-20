# The opencode Jupyter tool fits cell IDs to nbformat 4.5 and builds its ANSI pattern for the linter

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

nbformat 4.5 requires a cell `id` of 1 to 64 characters, letters, digits, `-` and `_`. Older notebooks have no cell IDs, and the tool addresses cells by ID. TypeScript linters such as Biome, which the editor setup runs on this code, flag a control character such as ESC inside a regular expression literal.

## Decision

`read` upgrades a notebook without IDs by giving each cell an 8-character ID from a hyphen-free UUID, raising `nbformat_minor` to 5, and writing the file back. `cleanAnsi` builds its pattern with `String.fromCharCode(0x1b)` and `new RegExp` rather than a regex literal containing `\x1b`.

## Consequences

Reading an old notebook modifies it on disk. Generated IDs must stay within the nbformat 4.5 character set and length. The ANSI pattern stays a constructed `RegExp` unless the linter rule is suppressed for that line.

## Where

- `agents/opencode/tool/jupyter.ts` (`generateCellId`, `upgradeNotebookCellIds`, `cleanAnsi`)
