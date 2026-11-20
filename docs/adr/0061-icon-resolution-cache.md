# Icon tinting and theme checks are cached per QML engine

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Qt SVG has no `currentColor` support. A bar holds many `ShellIcon` instances that read the same glyph files. A directory import of `ui/` and the `Stillsuit.Ui` module import resolve to different URLs, so each import style gets its own singleton instance. Lookups run inside bindings, and assigning a property that a binding read notifies every binding that read it, including the one doing the assignment. A plugin animating an icon's colour would create a new tint key per frame. `Quickshell.iconPath(name, true)` keeps `QIcon::fromTheme`'s fallbacks, such as `foo` standing in for `foo-bar`. A Qt window whose content looks unchanged does not draw a new frame.

## Decision

- `IconCache` writes the requested fill into the SVG markup before decoding, instead of tinting pixels afterwards, and caches markup per URL and tinted sources per URL and fill.
- Its `store` is a plain object mutated in place, never reassigned.
- The tinted cache starts over past `tintedLimit` (512) entries.
- Both import styles may hold their own instance; both stay correct, the second only repeats reads.
- `IconCheck.resolve` uses `iconPath(name, true)` as the usability test.
- `ShellAppIcon._requestFrame` calls `Window.window.update()` so the deferred theme check gets the next frame.
- `ShellIcon`'s image decodes at display size through `sourceSize` and does not enable mipmaps, which would only cost texture memory.

## Consequences

An icon fill cannot animate cheaply past 512 distinct colours. Assigning a new object to `store` would start a binding loop.

## Where

- `packages/stillsuit-shell/src/ui/IconCache.qml` (`store`, `tintedLimit`, `tinted`)
- `packages/stillsuit-shell/src/ui/IconCheck.js` (`resolve`)
- `packages/stillsuit-shell/src/ui/ShellAppIcon.qml` (`_requestFrame`)
- `packages/stillsuit-shell/src/ui/ShellIcon.qml` (`brand` image)
