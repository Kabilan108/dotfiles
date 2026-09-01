# Stillsuit design language

This is the approved visual contract for Stillsuit on Quickshell and Niri. The
native design lab in `packages/stillsuit-shell` is the visual reference. The
old HTML prototype is retired and must not be used to infer shell behavior or
panel composition.

The production source uses the approved v2 contract in
`packages/stillsuit-shell/schemas/theme.v2.json`. Deployment remains a separate
human gate; this document describes the source contract whether or not the
current desktop generation has been rebuilt.

## Approved baseline

The design lab was approved with these settings:

| Setting | Value |
|---|---|
| Theme | Catppuccin Mocha |
| Body type | Noto Sans |
| Monospace type | JetBrainsMono Nerd Font |
| Icons | Material Symbols Rounded |
| Bar | 26 px, anchored to the top edge |
| Workspaces | Inline |
| Surface opacity | 0.80 |
| Medium radius | 7 px |
| Motion scale | 0.55 |
| Accent | `#89b4fa` |
| Panel | `#181825` |
| Raised | `#313244` |
| Primary text | `#cdd6f4` |

These are defaults, not a frozen palette. The token model supports other
themes without changing component QML.

## Principles

1. One theme record owns the shell's visual language. Plugins do not carry
   private palettes or reinterpret shared roles.
2. Color names describe meaning. A component asks for panel, raised, selected,
   warning, or audio. It does not read a raw Catppuccin color.
3. The shell is compact but readable. Body copy uses a sans serif face. Codes,
   measurements, timestamps, and other telemetry use monospace.
4. Icons lead compact controls and bar clusters. Text follows when an icon
   alone would make the action unclear.
5. Motion explains state changes. It must not delay opening a panel or make a
   frequently used action feel theatrical.
6. Mock content in the design lab proves composition and states. It does not
   assign production features to panels.

## Theme model

The theme has three levels.

### Raw palette

The palette records named neutral and chromatic colors from the source theme.
Only the theme resolver reads it. Catppuccin Mocha is the canonical baseline,
but the schema does not depend on Base16 or on Catppuccin-specific slot names.

### Semantic roles

Semantic roles describe what a color means across the shell.

| Group | Roles |
|---|---|
| Background | canvas, desktop, scrim |
| Surface | bar, panel, raised, overlay, hover, pressed, selected |
| Content | primary, secondary, muted, disabled, inverse |
| Outline | subtle, default, strong, focus |
| Accent | primary, hover, pressed, subtle, on-accent |
| Status | info, success, warning, danger |
| Signal | audio, microphone, brightness, charging, recording |

Signal colors are not decoration. Green means audio, yellow means brightness,
pink means microphone or recording, and peach means charging. General active
state uses the blue accent.

### Component assignments

Component assignments map semantic meaning onto a reusable control. Plugin QML
uses these assignments or an explicitly documented semantic role. It never
reads the raw palette.

| Component | Contract |
|---|---|
| Bar | background, border, separator, workspace, and cluster states |
| Panel | background, border, section, hover, selected, danger, and shadow |
| Control | background, interaction states, focus, text, and on-active text |
| Notification | background, border, unread, info, success, warning, danger, and muted |
| OSD | border, track, fill, and text |

There is deliberately no `component.osd.background`. Every OSD reads
`semantic.surface.panel` directly. This is a design rule, not a default that a
theme may override.

## Type and icons

Noto Sans is the body family. Use it for labels, prose, notification bodies,
panel rows, and explanatory text.

JetBrainsMono Nerd Font is the monospace family. Use it for clocks, resource
readouts, percentages, identifiers, keyboard hints, and short uppercase
section labels.

Material Symbols Rounded is the icon family. Use the filled rounded vocabulary
consistently. Do not mix outlined and rounded symbols within a production
surface. Shared `ShellIcon` names are the only icon API exposed to plugins.

| Type role | Size |
|---|---|
| Body and label | 13 px |
| Caption | 11 px |
| Heading | 17 px |

Use regular, medium, and bold weights at 400, 500, and 700. Do not use body
text smaller than 11 px.

## Geometry and density

The base spacing unit is 4 px. Normal gaps and padding use multiples of that
unit. The approved component metrics are:

| Metric | Value |
|---|---|
| Small radius | 5 px |
| Medium radius | 7 px |
| Large radius | 11 px |
| Bar height | 26 px |
| Bar outer gap | 0 px |
| Bar inner gap | 7 px |
| Small, medium, large icons | 15, 18, 24 px |
| Panel width | 380 px |
| Panel padding | 16 px |
| Standard row height | 38 px |

Use the small radius for controls and contained row treatments. Use the medium
radius for the bar and OSDs. Use the large radius for panels and notification
cards.

The standard panel, bar, and notification opacity is 0.80. Raised controls and
OSDs may render opaquely while keeping their assigned surface color. The
approved effect defaults are 24 px blur and 0.50 shadow opacity. Legibility over
the wallpaper takes priority over showing more wallpaper through a panel.

## Surface rules

- `semantic.surface.panel` is the common dark panel color.
- `semantic.surface.raised` belongs to controls and contained sections. It is
  not a replacement panel background.
- Selected rows use the component's selected fill with no decorative outline.
- Failed rows use `component.panel.rowDanger` as a borderless tinted fill.
- Empty states center their icon and copy within the available section.
- Borders separate a whole panel or card. Do not add nested outlines to every
  button or row.
- Notification state color belongs in a compact tinted icon tile. Do not use a
  detached full-height stripe along the card edge.
- OSDs use `semantic.surface.panel`, the medium radius, the OSD border, and the
  semantic signal color appropriate to the value being changed.

## Bar

The bar is 26 px tall and anchored to the top edge with no outer gap. It spans
each output edge. This replaces the earlier floating treatment.

Workspace treatment is fixed to inline. Workspace pips and the Niri column
indicator share one horizontal line. The active workspace uses the primary
accent. Do not reintroduce the stacked workspace experiment.

The right side favors icon-led clusters for resources, connectivity, audio,
notifications, and battery. Active clusters use an accent-tinted background.
Each cluster must expose a clear accessible label even when the visible control
is icon-only.

## Controls and state ownership

Controls use the shared `ShellButton`, `ShellToggle`, `ShellSlider`,
`ShellText`, `ShellIcon`, `ShellSurface`, and `ShellBarCluster` components.
Freeze these contracts before rebuilding production panels.

Do Not Disturb belongs to notification behavior and its notification panel. A
network preview must not imply ownership of it. A network scan action is a
borderless, right-aligned text and icon action. Network rows reserve a fixed
icon column so labels align across connected, scanning, joining, off, and
failure states.

The design does not prescribe a consolidated media and quick-settings panel.
The old HTML demo is not a requirements source. Panel contents and ownership
must come from a functional inventory and an explicit panel review.

## Notification states

Notification views support unread, info, success, warning, danger, and muted
roles. The state changes the icon tile and relevant status content. The card
keeps one joined background and its normal border.

The notification service remains the owner of history, actions, timeout
policy, and Do Not Disturb behavior. Rebuilding a view must not weaken those
behavioral contracts.

## Motion

The approved motion scale is 0.55 against the base 120, 180, and 260 ms tiers.
The effective Catppuccin baseline is therefore 66, 99, and 143 ms. Use
out-cubic easing.

Animate opacity and transforms. Do not animate layout measurements. A gesture
tracks the pointer directly and animates only after release. Reduced-motion
mode resolves transitions immediately.

Panel-open performance is part of the design. A transition cannot hide slow
construction. Keep persistent or lazy-loaded views warm when measurements show
that creation time is visible.

## Implementation boundary

The design lab may stay as a regression and theme-development tool. Its mock
network and notification states are examples, not production data sources.

The next implementation phase is:

1. Review panel functionality and ownership one panel at a time.
2. Promote the approved v2 theme and freeze the shared component contracts in
   the production shell.
3. Rebuild approved panels with the frozen shared components.
4. Enable persistent Quickshell logging, then run the live soak after the UI
   pass.

Do not infer missing panel requirements from removed prototypes or old design
notes.
