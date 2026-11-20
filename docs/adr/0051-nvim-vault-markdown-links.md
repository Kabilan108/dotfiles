# Vault link tools skip code examples and follow markdown-oxide's ID rules

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Vault notes contain code and HTML examples with link syntax that must not be rewritten or resolved. Fenced Markdown code may itself inject a Markdown parser, so injected trees can contain links and definitions from examples. markdown-oxide 0.25.12 requires reference IDs of at least two characters and cannot parse IDs with whitespace, brackets or a leading caret. Terminal pastes can split even a single URL across several chunks. Bitbucket branch names can contain parentheses.

## Decision

- `MobergLinksToReferences` collects code, HTML and metadata ranges from the outer document first and ignores any link or definition inside them. It reuses only existing IDs markdown-oxide can parse and prefixes one-character IDs with `link-`. Before editing, it parses the buffer plus the new definitions with a separate string parser and refuses if any definition would land in an unfinished code fence or HTML block.
- Moberg URL formatting percent-encodes parentheses in destinations. Normal-mode `p`/`P` put through the expression register, which keeps counts, undo and dot-repeat and leaves the source register and system clipboard untouched. `vim.paste` buffers all chunks of a terminal paste before formatting.
- `note_link_yank` resolves reference definitions from the outer document only. For wikilinks it asks markdown-oxide for the definition at the start of the target, since the cursor may sit on an alias or heading, and deduplicates heading and block locations to one file.

## Consequences

If markdown-oxide relaxes its ID rules, the length and character checks can loosen. Any new link rewrite must apply the same code-example exclusion.

## Where

- `config/nvim/lua/custom/moberg_link_references.lua` (`convert`)
- `config/nvim/lua/custom/moberg_links.lua` (`link`, `put_keys`, `setup`)
- `config/nvim/lua/custom/note_link_yank.lua` (`reference`, `target`)
