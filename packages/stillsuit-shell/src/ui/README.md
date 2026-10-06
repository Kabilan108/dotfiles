# Shared Stillsuit UI contracts

Bar entries may expose a dynamic `property string tooltipText`. The bar host
displays it as plain text after 500 ms of hover, without pointer capture or
keyboard focus. An empty string disables the tooltip. `ShellBarCluster`
defaults it to the accessible name. Hover exit and panel selection hide it.

`ShellBarCluster.selected` means its panel is open. Use `contentColor` for
domain states such as low battery or charging. `secondaryIconName` (catalog)
or `secondaryIconSource` (image) plus `secondaryLabel` add a second icon/value
pair beside the first inside the same click target; `badgeIconName` is a small
corner overlay on the first icon.

`ShellIcon` renders a generated SVG from `icons/` (see `icons/README.md`) tinted
with the requested theme role. Setting `source` renders that image with its own
colors instead, falling back to the named icon while it is unavailable. `ShellEmptyRow` supplies the compact
icon-and-caption empty treatment used by the media section. The `IconCache`
singleton backs `ShellIcon`: it reads each glyph once and keeps one tinted
source per name and color. It is an implementation detail, not plugin API.

`ShellPanelHeader` supplies `title`, optional `subtitle`, the divider, and a
default trailing action slot. Actions remain caller-owned. `ShellScrollArea`
caps content at `maximumHeight` and adds clipping, bounded scrolling, and a
scrollbar. Use it for lists that can grow, starting with Bluetooth device lists.

`ShellTextField` is a themed single-line input with `text`, `placeholderText`,
an optional leading `iconName`, and an `accepted()` signal for Enter. Its
`keyPressed(event)` signal fires before the field edits text. A parent that
owns Up, Down, Tab, Enter, or a shortcut such as Ctrl+K accepts the event
there. Otherwise Qt's own editing shortcuts act first; Ctrl+K, for one,
deletes to the end of the line. Keys the field ignores, such as Escape,
keep propagating to parent items. The caret, selection, border, and
placeholder use theme roles. `selectAll()` and `clear()` act on the text.

`ShellAppIcon` shows an application icon from a freedesktop icon name,
loaded through Quickshell's icon provider, or from an absolute path. It
decodes at its display size and loads asynchronously. Until the icon loads,
or when it cannot be resolved, it shows a monogram of `fallbackLabel`, or the
catalog glyph `fallbackIconName` when the label is empty. `ready` reports
whether the icon itself loaded.

The provider draws a placeholder for names the theme lacks, so a themed name
also has to pass `Quickshell.iconPath(name, true)`. That check is a
synchronous theme lookup, and a cold one can take most of a second, so no
binding makes it. `IconCheck.js` looks each name up once per engine and every
icon shares the verdict. The lookup waits until the provider has loaded the
image on the pixmap reader thread, which pays the cold theme cost there, and
then for the window's next frame while `themeCheckAllowed` is true. Until a
name is checked its image bypasses the pixmap cache, so Ready always follows
a fresh provider lookup of that name. A surface that takes keyboard focus sets
`themeCheckAllowed: Window.active`: until the compositor has handed it the
keyboard, a lookup would delay the request for focus, and typing meant for it
would reach the previous window. An icon installed while the shell runs shows
after a restart.

These components consume theme-v2 semantic roles and component assignments.
Callers must not pass palette colors or add private color records. Direct
`color` overrides are reserved for values already obtained from a semantic or
component assignment.

`ShellAction` owns activation for `ShellButton`, `ShellToggle`, `ShellRow`, and
`ShellBarCluster`. Enter, Return, Space, and primary-pointer activation all call
the same guarded path. Disabled and busy actions do not emit. `accessibleName`
is the public naming hook for Quickshell 0.3, which cannot expose the full Qt
accessibility attached API used by newer runtimes. Labeled controls derive a
name from their label. Icon-only buttons and bar clusters derive a readable
fallback from `iconName`, but callers should set a more specific name when the
icon does not fully describe the action.

`ShellToggle` is owner-controlled. Activation emits `toggled(!checked)` and
never writes `checked`. The owner performs the operation and publishes the
accepted state back to the control. This prevents a failed service write from
briefly showing a state that never became true.

`ShellSlider` is owner-controlled. It clamps the owner's displayed value to the
inclusive `from` and `to` range and emits `moved(value)` for accepted pointer or
keyboard changes without writing `value` itself. The owner performs the
operation and publishes authoritative state back to the control, preserving
bindings across failures and external changes. It supports arrows, Page Up,
Page Down, Home, and End. Set `stepSize` when the default one-percent step is
not appropriate.

`ShellRow` reserves a fixed icon column by default so rows align across mixed
states. Selected and danger rows use borderless theme fills. `ShellSectionLabel`
provides the approved monospace uppercase section treatment. `ShellStatus` is
the compact inline status treatment. `ShellStateView` centers empty, loading,
and error content selected through its `mode` property and can expose one
guarded action.

Set `reducedMotion` on controls when the host requests it. Theme motion values
of zero also stop the busy indicator. Color and position transitions then
resolve immediately. None of these components animate width, height, implicit
size, padding, or another layout measurement.
