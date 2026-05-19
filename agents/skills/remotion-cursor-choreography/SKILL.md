---
name: remotion-cursor-choreography
description: Design and tune cursor movement for Remotion or product-demo videos. Use when adding cursor paths, hover states, click rings, cursor preview compositions, or fixing cursor target alignment.
---

# Remotion Cursor Choreography

Use this with a Remotion project when cursor movement is part of the demo.

## Core Model

- Treat cursor `x`/`y` as the hotspot, not the SVG top-left.
- The visible cursor usually extends down and right from the hotspot.
- Tune the hotspot to the intended click target; tune the visible shape afterward if it reads awkwardly.
- If the product surface is scaled or translated, manually re-tune the cursor coordinates in composition space.

## Workflow

1. Identify the target element and frame range.
2. Decide the cursor beat:
   - enter
   - move
   - hover
   - click
   - cut or exit
3. Wire hover state to begin as soon as the hotspot reaches the element.
4. Wire click ring to the click frame.
5. Render stills at:
   - cursor start
   - hover start
   - click frame
   - first frame after cut
6. Tune coordinates and timing from stills.

## Timing Guidance

- Cursor movement should usually start at the same time as related callouts, not after them.
- Hover-to-click delay should be short unless the hover state itself needs to be read.
- Cut soon after the click when the click changes pages.
- Do not fade the cursor in mid-screen. Bring it from an edge or from the prior click location when possible.

## Coordinate Tuning

When a target looks off:

- If the click ring is wrong, adjust hotspot `x`/`y`.
- If the ring is right but the cursor graphic reads wrong, adjust cursor SVG hotspot constants or target slightly.
- If the cursor is correct before a zoom/scroll but wrong after it, the asset transform changed; tune the later scene independently.

Example pattern:

```tsx
const cursorMove = progressFor(frame, 12, 108);
const hover = progressFor(frame, 88, 112);

<Cursor
  x={interpolate(cursorMove, [0, 1], [startX, targetX])}
  y={interpolate(cursorMove, [0, 1], [startY, targetY])}
  opacity={1}
  frame={frame}
  clickFrame={126}
/>
```

## Still Checks

```bash
pnpm exec remotion still src/index.ts <Composition> /tmp/cursor-click.png --frame=<clickFrame>
```

Inspect the still visually. Do not rely on coordinate math alone.

## Common Fixes

- Cursor appears on the wrong row: adjust final `y`, then align hover timing to the new arrival.
- Cursor lands below the button: move final `y` higher, not necessarily `x`.
- Click ring is outside the button: adjust hotspot target, not SVG top-left.
- Cursor pops into view: add an entry path from a corner or previous interaction point.
