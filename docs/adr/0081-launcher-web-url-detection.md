# Launcher web provider detects URLs narrowly

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The launcher offers an "Open" row when the query looks like a URL. Loose
detection opens the wrong thing: "https://bank.com@evil.example" hides its real
host behind userinfo, file names such as "notes.md" or "main.go" look like
domains, and reverse-DNS app ids such as "org.gnome.Nautilus" look like hosts.

## Decision

An Open row is offered only for http(s) URLs. Explicit URLs need `http://` or
`https://` followed by a host without "@" and an optional path, query or
fragment, with no whitespace. Bare domains are dot-separated DNS labels ending
in a two-letter TLD or one from `COMMON_TLDS`, with optional port and path;
`https://` is prepended. TLDs that are also common file extensions are not
inferred; the user types the scheme for those. Reverse-DNS app ids end in a
word that is not a known TLD, so they are not URLs.

An explicit URL ranks near the top (`URL_SCORE`); an inferred one ranks below
every other match, above the trailing search row. A query starting with "!" is
a search-engine bang: its search row ranks first (`BANG_SCORE`) and the "!"
goes to the engine unchanged.

## Consequences

Adding a TLD to `COMMON_TLDS` can make file names open as URLs.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/launcher/model/providers/web.js` (`EXPLICIT_URL`, `BARE_URL`, `COMMON_TLDS`, scores)
