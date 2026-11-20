# Stillsuit UI notes

- Mutate `store` in `IconCache.qml` in place; never assign it a new object. Lookups run inside bindings, and assigning a property a binding read notifies every binding that read it, including the one doing the assignment, which is a binding loop.
- `tintedLimit` (512) in `IconCache.qml` bounds the tinted cache, which starts over when full. A plugin that animates an icon's colour creates one key per frame, so a fill cannot animate cheaply past 512 distinct colours.
- Expect two `IconCache` instances when code mixes a directory import of this folder with the `Stillsuit.Ui` module import. The two resolve to different URLs, so each gets its own singleton; both stay correct and the second only repeats file reads.
- Keep the `Window.window.update()` call in `ShellAppIcon.qml` (`_requestFrame`). The deferred theme check runs on the window's next frame, and a Qt window whose content looks unchanged does not draw one.
