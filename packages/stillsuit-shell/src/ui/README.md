# Shared Stillsuit UI contracts

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
