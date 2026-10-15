# Resources

The bar shows local CPU and memory use. Clicking opens the Performance panel,
which refreshes the local machine every three seconds while open and requests
one fresh PC sample. The refresh button requests both machines again.

The tooltip has a laptop row and a PC row, identified by Lucide SVG icons. Hover
requests a PC sample if the cached one is older than 30 seconds. Requests are
shared across outputs, with at most one request per machine in flight. The PC
row shows CPU and memory only; failed requests preserve the last good sample and
mark it unavailable. Sample age appears in the panel, where PC samples older
than 30 seconds are marked stale.

The PC target comes from `~/.config/fleet/fleet.json`: the first accessible
machine with the `agent-worker` role. The desktop does not query the laptop.
The collector is streamed to `<host>-agent` over SSH, so no remote installation
or persistent service is needed. Both machines use their existing Home Manager
Python installation. Local Python is resolved through
`/etc/profiles/per-user/$USER/bin/python3`; SSH uses the NixOS system profile.

The panel uses the same one-line meter for CPU, memory, PC GPU compute, and PC
VRAM: label, bar, detail, percent. Each host measures its columns from the
widest expected text, so every bar in the panel starts and ends at the same x.
Laptop GPU telemetry is hidden. CPU and GPU temperatures sit alongside the
matching utilization values, and each machine has a compact pressure row whose
values brighten from 1% and warn from 10%. A dot beside the sample age turns
yellow when the PC sample is stale or the last request failed.
Missing optional metrics remain unavailable. CPU utilization uses a half-second
sample. The collector also supplies load, swap, disk, network, and GPU power
data, which the compact panel does not display.

Pressure is the percentage of time during which at least one task waited for CPU, memory,
or I/O over the last ten seconds, using the kernel's `some avg10` fields.

Metric definitions follow the kernel's [proc documentation](https://docs.kernel.org/filesystems/proc.html),
[I/O statistics](https://docs.kernel.org/admin-guide/iostats.html),
[pressure documentation](https://docs.kernel.org/accounting/psi.html), and
NVIDIA's [nvidia-smi documentation](https://docs.nvidia.com/deploy/nvidia-smi/).

Run the resource regressions through the dotfiles dev shell:

```sh
direnv exec "$PWD" bash packages/stillsuit-shell/src/tests/power-resources/run-fixtures.sh
direnv exec "$PWD" bash packages/stillsuit-shell/src/tests/d4-widgets/run-fixtures.sh
```
