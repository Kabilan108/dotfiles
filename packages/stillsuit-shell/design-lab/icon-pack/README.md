# Stillsuit icon pack

`soft/` is the selected Soft family, one SVG per name in `ShellIcon`'s catalog.
`build.py` holds the shared outline primitives and the build entry point;
`soft_v2.py` holds the Soft silhouettes. `gallery.template.html` is the source
of the generated review page `index.html`, which is not tracked.

From the repository root:

```sh
direnv exec "$PWD" python packages/stillsuit-shell/design-lab/icon-pack/build.py            # soft/ + index.html
direnv exec "$PWD" python packages/stillsuit-shell/design-lab/icon-pack/build.py --install  # also copy into src/ui/icons/
```

The generator uses only the Python standard library. All SVGs use a 24 × 24
viewBox and inherited fill, with strokes expanded into polygons for ShellIcon's
fill-injection tinting. Coordinates are written with two decimals; round caps
are emitted only at terminals and at turns of 15° or more, with small wedges
covering the joins between near-collinear segments. Both are visually
lossless at shell sizes and keep the files a third of the naive output.

The workbench (`stillsuit-workbench`, then `stillsuit-workbench open
icon-gallery`) renders the installed pack through the real `ShellIcon` at every
size and tint role.

## Design rules

The family uses a 1.8-unit outline, rounded terminals, continuous rounded
corners, open counters, and simplified details for 15–24 px rendering. Play is
a rounded solid triangle; pause uses outlined capsules. CPU and RAM have
different silhouettes. Ethernet is a branching network. Record is a ring with
a solid center. The circle and three-dot primitives are unchanged.

Batteries use a horizontal housing with the terminal on the right and four
charge segments. The existing eight catalog states remain distinct: 0, 12.5,
25, 37.5, 50, 75, 87.5, and 100 percent visual fill. These are representative
glyphs, not a change to the shell's percentage thresholds. Half-bands supply
the intermediate states. Charging uses a custom bolt inside the same housing;
the bolt, alert, and question symbols stay upright.

RAM has thinner, evenly spaced chips and a solid lower strip. Agent uses a
low rectangular head with a ring antenna. Delete has straight sides, a rounded
base and handle. VPN is a filled badge with transparent letter cutouts.

## Shape references

These user-selected references informed the redraws. Their SVG path data and
colors are not embedded in the pack; every glyph was redrawn. The RAM
reference is simplified to three chips to leave visible space at small sizes.

| Shape | Reference |
| --- | --- |
| Wi-Fi | https://www.svgrepo.com/svg/326461/wifi-outline |
| Battery 0 | https://www.svgrepo.com/svg/498999/battery-0 |
| Battery 25 | https://www.svgrepo.com/svg/499002/battery-25 |
| Battery 50 | https://www.svgrepo.com/svg/499003/battery-50 |
| Battery 75 | https://www.svgrepo.com/svg/499001/battery-75 |
| Battery 100 | https://www.svgrepo.com/svg/499000/battery-100 |
| CPU | https://www.svgrepo.com/svg/521584/cpu |
| RAM | https://www.svgrepo.com/svg/157926/ram-memory |
| Ethernet | https://www.svgrepo.com/svg/435850/ethernet |
| Folder | https://www.svgrepo.com/svg/532810/folder |
| Pause | https://www.svgrepo.com/svg/522621/pause |
| Play | https://www.svgrepo.com/svg/522226/play |
| Settings | https://www.svgrepo.com/svg/435948/settings |
| Copy | https://www.svgrepo.com/svg/510939/copy |
| Danger | https://www.svgrepo.com/svg/497000/danger |
| Record | https://www.svgrepo.com/svg/501327/record |
| Agent | https://www.svgrepo.com/svg/389050/bot |
| Delete | https://www.svgrepo.com/svg/502614/delete |
| Forward 10 | https://www.svgrepo.com/svg/495319/forward-10-seconds |
| Replay 10 | https://www.svgrepo.com/svg/495033/backward-10-seconds |
| Refresh | https://www.svgrepo.com/svg/522638/refresh |
| Repeat | https://www.svgrepo.com/svg/522640/repeat |
| Shuffle | https://www.svgrepo.com/svg/432299/shuffle |
| VPN | https://www.svgrepo.com/svg/442309/network-vpn-symbolic |
