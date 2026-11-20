# edit-block-list refuses to run without a terminal

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

agenix replaces a secret's contents from stdin when stdin is not a terminal. `edit-block-list` is meant to edit the existing encrypted list, not import a new one.

## Decision

The script exits with an error unless both stdin and stdout are terminals.

## Consequences

The command cannot be scripted or piped. Replacing the list wholesale needs agenix directly.

## Where

- `bin/edit-block-list`
