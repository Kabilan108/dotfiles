# Stillsuit icons

Original Stillsuit glyphs, generated from `design-lab/icon-pack` (`build.py`
draws the shared primitives, `soft_v2.py` the Soft silhouettes). They are not
vendored from any icon set. Every file here is a 24 × 24 viewBox with one
`<path>` and no `fill`, `stroke`, or `style` attributes: `ShellIcon` injects a
root `fill` for the requested theme role, so any fixed color or stroke would
break tinting. Transparent detail such as the VPN lettering is cut with
contour winding, not with extra fills.

`notifications` and `notifications-off` use the CC0 Bell and Bell Slash
vectors supplied through SVG Repo. Their normalized source files live in
`design-lab/icon-pack/sources/` so regeneration preserves the original paths.

Edit the geometry sources, never these files, then regenerate and install:

```sh
direnv exec "$PWD" python packages/stillsuit-shell/design-lab/icon-pack/build.py --install
```

The catalog list in `ShellIcon.qml` is the source of truth for names; the
generator reads it, so adding an icon means adding its name there and its
geometry in the generator.
