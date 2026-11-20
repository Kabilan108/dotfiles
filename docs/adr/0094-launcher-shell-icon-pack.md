# Launcher non-app rows use Stillsuit icon pack glyphs

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Icon themes that ship only symbolic names cannot resolve the non-symbolic freedesktop names a launcher would ask for on power, profile, clipboard and similar rows. The theme lookup then falls back to a letter monogram.

## Decision

Non-app rows name a glyph from Stillsuit's own icon pack (`ui/icons`) as `shell:<name>`. App and window rows keep freedesktop theme icons. The engine test checks every non-app row names an existing pack glyph. The launcher QML fixture runs with no icon theme and checks that power rows render pack glyphs, not theme lookups or letters.

## Consequences

Each new non-app row needs a glyph in `ui/icons`. App and window icons still depend on the system theme.

## Where

- `packages/stillsuit-shell/src/plugins/builtin/launcher/model/Engine.js` (row `icon` contract)
- `packages/stillsuit-shell/src/ui/icons`
- `packages/stillsuit-shell/src/tests/launcher/engine.test.js`
- `packages/stillsuit-shell/src/tests/launcher-qml/fixture-shell.qml` (step "power rows render pack glyphs, not theme lookups or letters")
