# Stillsuit Shell — Design Philosophy & Handoff

A cohesive desktop shell concept for **Quickshell** on **Niri / NixOS**, themed
loosely around Dune ("stillsuit"). This document is the design contract for the
implementation; the HTML prototype (`Stillsuit Shell.html`) is the visual
reference. Treat the prototype as *intent*, not as code to port — rebuild it
natively in QML.

---

## 1. First principles

1. **One language, everywhere.** Every surface — bar, launcher, OSDs,
   notifications, panels — is the *same* glass card with the *same* hairline,
   radius, blur, type and spacing. No surface invents its own treatment. If a
   new surface is needed, it is assembled from the existing primitives.
2. **Theme-agnostic via base16.** Nothing hardcodes a colour. Every colour is a
   semantic role resolved from the 16 base16 slots. Swap the scheme (Stylix)
   and the whole shell reskins with zero layout change. Catppuccin Mocha is the
   reference scheme, not a dependency.
3. **Quiet, dense, modern.** Compact spacing, monospace throughout, thin
   single-weight icons, near-instant motion. The shell informs and gets out of
   the way. No emoji, no gradients-as-decoration, no faux-skeuomorphism.
4. **Legible over anything.** Surfaces stay readable over a busy photographic
   wallpaper *and* a flat one. This is a hard constraint (see §5).

---

## 2. The token system

Implement these as a single resolved palette/style object the whole shell reads
from. The 16 inputs come from Stylix; everything else is derived.

### Inputs — base16 (Stylix provides these)
`base00`…`base0F`. Conventional meaning: `base00` darkest bg → `base05` default
fg → `base07` brightest; `base08`–`base0F` are the accents (red, orange, yellow,
green, cyan, blue, magenta, brown).

### Derived semantic roles
| Role | Source | Use |
|---|---|---|
| `accent` | `base0D` (blue) | **all** interactive / focused / active state |
| `accent2` | accent mixed 78% with `base05` | accent text on dark |
| `text` | `base05` | primary text |
| `dim` | `base05`·74% + `base04` | secondary text / inactive icons |
| `faint` | `base05`·52% + `base04` | tertiary text, timestamps, meta |
| `bright` | `base0A` (yellow) | **brightness** OSD only |
| `vol` | `base0B` (green) | **volume** OSD / output level only |
| `mic` | `base08` (red) | **microphone** / input level only |
| `charge` | `base09` (orange) | **charging** only |
| `ok` / `warn` | `base0B` / `base08` | success / low-battery, alerts |

**Accent rule:** exactly one primary accent (`base0D`) carries every
interactive and active state. Semantic colours (`bright`/`vol`/`mic`/`charge`)
appear *only* where they encode that specific meaning — never decoratively.

### Locked constants
| Token | Value | Notes |
|---|---|---|
| Corner radius | **5 px** | shell-wide. Inner elements `radius − 1`. OSD & dictation pills are the exception: **fully rounded** (999px). |
| Hairline border | `rgba(255,255,255, 0.10)`, 1px | the *only* separation line |
| Blur | **22 px** backdrop blur | + `saturate(1.1)` |
| Surface fill | ~**85%** over a darkened backdrop | see §5 |
| Font | **IBM Plex Mono** | monospace everywhere; tabular numerals on |
| Base size | **13 px**; never below 10px | |
| Density unit | **4 px** | gaps are multiples of it (4/8/12) |
| Shadow | `0 18px 50px -12px rgba(0,0,0,.62)` | one elevation only |
| Motion | 120–160 ms, `cubic-bezier(.2,.7,.2,1)` | transform/opacity only; snappy |

---

## 3. Surface inventory

All are independent Quickshell windows/layers, summoned by Niri keybinds or IPC
events. (The prototype's bottom "preview" dock is a demo harness only — it has
no place in the real shell.)

- **Top bar** — floating, detached, 8px margins, ~38px tall, rounded. Three
  zones: *left* workspaces + columns, *centre* date/time, *right* clustered
  tray. Details in §4.
- **Launcher** (Walker/elephant replacement) — centred glass card, search field
  + result rows + footer action pill. One shell, four modes: **app**,
  **window**, **clipboard** (two-pane with preview), **power**. Row hotkeys are
  quiet plain-mono `F1…F4`; the footer's primary action is a pill with the key
  glyph *inside* it.
- **OSDs** — brightness / volume / mic. Fully-rounded pill: semantic-coloured
  icon (no halo, no box) + progress track. No numeric readout, no label.
- **Dictation indicator** — fully-rounded pill, animated waveform only. No mic
  icon, no text.
- **Notifications** — transient **toast** (top-right) and a **history panel**
  (header "N recent" + "clear all"). Borderless cards: a bare accent-coloured
  glyph, app name, title, body, timestamp. Hovering a card reveals a close `×`
  and shifts the timestamp left to make room (never overlap).
- **Media panel** — art, title/artist, scrubber, transport (primary = filled
  accent circle), output/input level sliders, output-device picker.
- **Quick settings** — Wi-Fi/Bluetooth/DND/Power-saver toggles, brightness &
  volume sliders, connected Bluetooth devices, and a **Nearby** section that is
  empty until you press **Scan** (then reveals discovered devices).
- **Battery** — large %, fuel bar, stat grid (size / time / threshold /
  discharge rate), power-profile segmented control. (Reference: Omarchy.)

---

## 4. Top bar specifics

- **Workspaces (Niri).** Niri scrolls *columns* horizontally within a
  workspace. Two layouts were designed (pick per taste; default is the first):
  - **inline** — workspace **pips** (active pip elongates) · `|` divider · a
    compact **column indicator**: bare blocks where the focused column is a
    solid accent block, the rest are dim ticks. No surrounding box.
  - **stacked** — `X/Y` count + a *vertical* card-stack: workspaces stacked,
    active centred and accent-bordered with its column blocks inside, neighbours
    peeking above/below behind a soft fade; slides vertically as you switch.
  Both must be driven by Niri's real workspace/column state (IPC), not faked.
- **Clustered tray.** The right side is grouped into clickable clusters, each
  opening the relevant panel: resources (cpu/mem, display-only) · connectivity
  (wifi+bt → quick settings) · audio (→ media) · notifications (→ history,
  badge = unread count) · battery (→ battery panel). Active cluster shows an
  accent-tinted background.

---

## 5. The legibility technique (important)

Translucent surfaces over a *bright* wallpaper region wash out: backdrop-blur
pulls the bright pixels through and text loses contrast. The fix used here is
**darken the backdrop, don't just lower opacity**:

```
backdrop-filter: blur(22px) saturate(1.1) brightness(0.5);
background: <panelbase> at ~85%;   /* panelbase = base00 darkened ~34% */
text-shadow: 0 1px 3px rgba(0,0,0,.52);  /* faint scrim on text */
```

This keeps the glassy, blurred quality while guaranteeing readable text over any
wallpaper. In QML this maps to a `MultiEffect`/blur source plus a semi-opaque
dark `Rectangle` overlay — replicate the *darkening*, not only the alpha.

---

## 6. Implementation notes for Quickshell

- Build a single **Theme singleton** holding the resolved tokens of §2; bind
  every component to it. Re-resolving from new base16 values is the entire
  retheme path.
- Each surface = its own `PanelWindow` / layer-shell surface. Drive
  show/hide and all live data from Niri IPC, MPRIS, PipeWire/WirePlumber,
  UPower, BlueZ, NetworkManager, and the notification server — never poll fake
  state.
- Icons: one thin-stroke line set (the prototype uses Lucide at stroke-width
  1.6). Pick a single QML icon source and keep stroke weight uniform.
- Motion: 120–160ms ease on transform/opacity. Avoid long or bouncy
  transitions.
- Respect the **44px minimum** hit target for anything clickable even though the
  visuals are dense.
- Keep the Dune flavour *restrained*: it lives in naming and the wallpaper, not
  in chrome. (e.g. battery panel's "water reserves" label is optional flavour —
  drop to plain "Battery" if it ever reads as costume.)

---

## 7. What's intentionally NOT here

No system tray spillover, no calendar (removed by design), no decorative
gradients, no per-surface accent colours, no emoji. Add new surfaces only by
composing the existing primitives so the system stays coherent.
