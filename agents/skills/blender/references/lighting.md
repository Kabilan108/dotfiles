# Lighting, materials, and colour for realistic shots

Read this for product shots, interiors, and any render meant to look like a photograph.

## Light levels

- **Falloff:** light energy falls off with distance². About 1000 W suits a room-sized scene lit
  from 3–5 m away. A 10 cm object lit from 0.4 m needs single-digit watts. Sun energy is W/m², and
  1–10 is typical.
- **Colour temperature:** `bk.light(..., temperature=2700)` for warm bulbs, 5500–6500 for daylight.
  To mix warm and cool, set `C.scene.view_settings.use_white_balance = True` and choose
  `white_balance_temperature` between the two sources; a lower value makes the image cooler.
- **Interiors:** exposure (`C.scene.view_settings.exposure`) of +2 to +3 EV is normal. Put an
  area light over each window with `light.cycles.is_portal = True` so HDRI light enters cleanly.
  Rotate the HDRI (`bk.hdri(..., rotation_deg=)`) so its sun agrees with any sun lamp you add,
  or leave the sun lamp out.
- **Framing interiors:** auto-framed views put the camera outside the room. Use
  `render --views camera`, or `--hide 'Wall*' Ceiling` with `--target OBJ` for close-ups.

## Materials

- **Glass:** a Principled glass pane darkens the light coming through a window. Use a
  Transparent + Glossy mix for panes. Imported glTF glass (for example a picture-frame `_glass`)
  can render black in Cycles; replace it.
- **Textures:** `bk.pbr_material` projects in object space. Build geometry with `bk.box`/`bk.extrude`,
  or apply scale, so textures keep their size. `blend polyhaven get` prints the texture's real
  size and the matching `scale=` value.
- **Metal and gloss:** they need an environment to reflect, so light with an HDRI before judging them.
- **Backdrops:** make ground and backdrop planes extend past the camera's view. Mark curved
  cycloramas with `obj["blend_frame"] = False` so auto-framing ignores them.
- **Mix nodes:** use `bk.socket(node, "A_Color")` to get sockets by identifier.

## Product and glass shots

- **Liquid in glass:** model the liquid about 0.2 mm larger than the cavity so the surfaces
  overlap rather than touch. Colour it with Volume Absorption so thick regions read darker.
  Raise `C.scene.cycles.transmission_bounces` (16–24).
- **Glass edges:** define them with dark-field rim strips, meaning lights behind and to the
  sides so only the edges catch light: `bk.light("AREA", ..., size=0.05, size_y=1,
  visible_camera=False)`. Keep them off a mirror floor or foreground props with
  `bk.exclude_light(strip, floor, *petals)`.
- **Black studio sweep:** `bk.hdri(path, background_color="#000000")` keeps the HDRI in
  reflections while the camera sees black.
- **Depth of field** blurs reflections of distant lights into fat white blocks, because the
  reflected image sits far behind the focus plane. Move such lights closer or remove them.
- **Saturated colours** (red petals, fabric) wash toward white under AgX when bright
  highlights hit them. Lower their specular (`Specular_IOR_Level=0`) and keep strong lights
  off them.

## Colour management

The default view transform is AgX. It suits photoreal work: use `view_settings.look =
"AgX - Medium High Contrast"` or `"AgX - Punchy"` for more contrast. For flat, stylized, or
low-poly palettes, AgX desaturates colours, so switch to `view_transform = "Standard"`.
