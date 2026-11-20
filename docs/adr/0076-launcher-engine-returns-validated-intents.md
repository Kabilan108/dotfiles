# Launcher engine is injected with its modules and returns validated intents

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

QML JavaScript imports cannot `require()` each other, so the engine cannot
load the matcher, history, query parser or providers itself. Rows pass through
QML models, which copy them, and V4 still lets `push()` and index writes
through on frozen arrays. Rows carry data that becomes app launches, window
focus, session actions and URL opens.

## Decision

The service imports every module and passes them to `Engine.create({Matcher,
History, Query, providers})`. `engine.prepare(env)` runs when a snapshot
changes, `engine.run(input, mode, env)` per keystroke, and
`engine.activate(row, actionId)` on Enter. Prepared haystacks are cached per
snapshot by `env.revisions[<snapshot>]` when given, else by object identity.

Returned rows are deeply frozen copies. `activate()` only accepts rows from the
most recent `run()`, matched by key and generation, and activates the engine's
private snapshot of that row, so fields edited on a copy are ignored. Rows from
earlier runs return null.

`activate()` returns a validated intent or null, never a command line. Each
intent type lists its fields in `INTENT_FIELDS` with kinds `id`, `text`,
`path`, `url` (http or https, no whitespace), `windowId` and `session`; any
other field rejects the intent. `validIntent` never throws: hostile getters or
proxies count as invalid.

Query parsing recognises a prefix only as the first character of the raw
input, so "foo/bar" stays an app query. Input is cut to its limit without
splitting a surrogate pair and lone surrogates become U+FFFD, so the text is
safe for `encodeURIComponent`.

## Consequences

The service is the only place that turns an intent into a process or IPC
call. A new intent type needs an `INTENT_FIELDS` entry before it can be
returned.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/launcher/model/Engine.js` (`create`, `INTENT_FIELDS`, `validIntent`, `activate`, `plainCopy`)
- `packages/stillsuit-shell/src/plugins/builtin/launcher/model/Query.js` (`PREFIXES`, `wellFormed`)
- `packages/stillsuit-shell/src/plugins/builtin/launcher/Service.qml` (`engine`)
