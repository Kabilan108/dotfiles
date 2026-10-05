# Clipboard history plugin

`stillsuit.clipboard` is a service-only plugin that keeps a clipboard history
for the launcher. A supervised `wl-paste --watch` runs
`stillsuit-clipboard-collector emit` once per selection change. The collector
classifies the offer from its MIME types and source markers, stores accepted
payloads as content-addressed blobs under `<stateRoot>/clipboard/blobs`, and
prints one JSON event. `Service.qml` is the only writer of
`<stateRoot>/clipboard/history.v1.json`.

## Settings

| Setting | Default | Meaning |
|---|---|---|
| `collectorPath`, `wlPastePath`, `wlCopyPath` | none | Absolute store paths. Without them the service reports `status: "error"`. |
| `niriPath` | none | Absolute path to `niri`, used to attribute unattributed GTK3 text copies (rule 4). Without it every such copy is skipped. |
| `focusSettleMs` | 2000 | A focus younger than this is unsettled; GTK3 text copies made in it are not recorded (rule 4). |
| `maxItems` | 200 | History cap. |
| `ttlHours` | 72 | Entries expire this long after their last use. |
| `maxTextBytes`, `maxImageBytes` | 1 MiB, 20 MiB | Larger payloads are skipped. |
| `clearPurgeWindowSec` | 330 | How long after a capture a clear can still purge it. |
| `secretSourcePrefixes` | Bitwarden's Chromium extension, the vault origin | Source URL prefixes whose copies are skipped. |
| `unattributedFirefox` | `"skip"` | `"skip"` or `"record"`; see rule 4. |
| `geckoAppIds` | Zen, Firefox and LibreWolf app ids | Python regular expression, searched in the `app_id` of the focused window (rule 4). |
| `gcGraceSec` | 120 | Grace period for the crash-leftover sweep. |

## What is never recorded

The collector checks these rules in order, before reading any payload; rule 4
is checked again after the last payload read:

1. The offer includes `x-kde-passwordManagerHint` (Bitwarden desktop, KeePassXC,
   Firefox private windows), or `CLIPBOARD_STATE` is `sensitive`.
2. A source marker is offered but cannot be read or decoded.
3. `chromium/x-source-url` or `text/x-moz-url-priv` starts with a configured
   secret source prefix. This catches Bitwarden in Chromium and Helium (its
   popup and offscreen document) and the web vault in either browser.
4. With `unattributedFirefox = "skip"`, an unattributed Gecko copy: the offer
   has GTK3's plain-text shape (`SAVE_TARGETS`, `COMPOUND_TEXT` and
   `text/plain;charset=utf-8` twice), no page origin in
   `text/x-moz-url-priv`, and niri does not vouch for the focus. The
   collector runs `niri msg --json windows` before reading the payload and
   again after its last read. It records the copy only when both answers name
   the same focused window with the same focus timestamp, that window's
   `app_id` does not match `geckoAppIds`, and its focus is settled: niri has
   stamped it, its stamp is the newest of all windows, and it is at least
   `focusSettleMs` old. Anything else skips the copy, including niri not being
   configured, failing, taking longer than 300 ms or naming no single focused
   window.

Rule 4 exists because Firefox gives extension copies no origin. In a Wayland
probe (Firefox 157, Bitwarden extension 2026.9.3), the extension's password
copy, an address-bar copy and the extension's clear all offered the same
types, with no marker; in `"record"` mode that match is what lets the clear
purge the copy (see Clears). Page selections and web-vault copies carry their
origin and are judged by rule 3. Firefox gets these types from GTK3's
`gtk_clipboard_set_text()`, so every GTK3 app's text copy offers them too;
the MIME types alone cannot tell a GTK3 app from the browser. niri's focus
history can: the Bitwarden extension's popup belongs to the browser window.
niri is only asked about offers with this shape.

The focused window alone is not enough: copy a password in Zen, Alt-Tab to a
GTK3 app, and by the time `emit` asks (tens of milliseconds later) the GTK3
app is focused. niri's window list gives every window a `focus_timestamp`
from `CLOCK_MONOTONIC` (niri 26.04, `src/utils/mod.rs` `get_monotonic_time`),
which the collector compares with its own `CLOCK_MONOTONIC`. niri commits a
refocused window's timestamp only after `recent-windows` debounce (750 ms by
default) or its first key press (`src/niri.rs`, `mru_apply_keyboard_commit`);
until then the focused window has no timestamp or an older one than the
window it replaced. The collector does not try to name the window focused
before: a stop in a third app on the way from Zen would hide Zen from that
check. One answer is not enough either, because focus can change while the
payload is read: switch to Zen and copy a password between the first answer
and the read, and the payload comes from Zen. The second answer then shows
Zen, an unsettled focus or another window.

The cost: with `"skip"`, Zen and Firefox address-bar copies (and copies from
any other extension or browser UI) never enter history. GTK3 copies made
within `focusSettleMs` (2 s) of a focus change, or before niri has stamped the
focus, are not recorded either. Other GTK3 copies are recorded. Chromium
address-bar copies are not affected; they have no GTK3 targets.

What remains: separate `wl-paste` calls cannot be tied to one Wayland offer,
so every text copy whose classification (types, markers, both payload reads
and, for GTK3-shaped offers, both niri samples) takes longer than 1 s is
skipped (the default; tests raise it through
`STILLSUIT_CLIPBOARD_TEXT_GATE_SEC`). It normally takes 20-40 ms; a VM
encoding a screen recording in software measured 250-280 ms. Within that
window a Bitwarden copy can still be recorded if the clipboard flips between a
benign offer and the secret more than once (A, B, A, B, each switch and copy
under about 330 ms), or if the user enters a browser, copies and leaves it
again within niri's 750 ms debounce using only the mouse, so niri never stamps
the visit. Both take several deliberate actions in under a second.

## Clears

Bitwarden's extension clears the clipboard after its timer. Firefox writes a
zero-byte text offer with the unattributed Gecko shape of rule 4; Chromium
offers only `chromium/x-source-url` (the extension's offscreen document) and
no text. A text offer whose content is `""`, `"\u0000"` or `" "` is never
recorded. Only in `"record"` mode, and only when the offer has the
unattributed Gecko shape, is it a clear, which purges the newest entry when that entry was the previous capture, is
younger than `clearPurgeWindowSec`, and was copied from an offer with the
same MIME types, duplicates and order included. The collector sends a `shape`
with each text and clear event, a sha256 prefix of the offered type list, and
the history keeps the capture's shape with its entry. This matters in
`"record"` mode, where the extension's copy was recorded: Bitwarden's Firefox
clear offers exactly the types of its copy (rule 4). An app that offers text
and then sends no bytes also reads as an empty payload, since `wl-paste`
ignores its reader's exit status. In `"skip"` mode, or without the Gecko
shape, that read is skipped as empty and purges nothing, even when it offers the newest entry's types (two
`wl-copy` offers, the second of which fails). Entries saved before
shapes were recorded are never purged. A `CLIPBOARD_STATE=nil` event, which both browsers send
before a copy or clear, neither purges nor detaches the clear from the entry
it belongs to. The Chromium clear has no text, so it is skipped and never
purges.

## Removal

Dropping an entry (remove, clear, purge, expiry, cap) queues its blob for the
collector's `rm --before-ms <decision time>`, which keeps a blob a newer
capture replaced after the decision. The history without the dropped entries,
with the queued blobs as `pendingRemovals`, is written synchronously and read
back before any `rm` starts, so a crash never leaves entries or previews for
deleted blobs. A failed write is retried with backoff, and `rm` waits for it.
Each blob is queued once, under its latest decision; nothing is dropped to
bound the queue. A batch stays in `pendingRemovals` until its `rm` exits
successfully, and a failed `rm` is retried with backoff. On shutdown, the
batches known to be on disk are also handed to detached `rm` processes, and
the next start runs whatever is still pending. Blob replacement and
`rm`/`gc`'s check-then-unlink share an exclusive lock on
`<stateRoot>/clipboard/.lock`. `gc` never deletes a temp file younger than
10 minutes, since a capture may still be staging it.

`gc` sweeps crash leftovers older than `gcGraceSec`. It does not run while a
write that drops entries has not been read back; a sweep asked for meanwhile
runs once one has. Its `--keep` list is every live entry plus every entry of
the last history read back from disk. A sweep reports when the first file it
deferred becomes eligible (`nextEligibleMs`), and the service sweeps again
then, at most once per 10 minutes.

When `copy` finds an entry's blob missing or not holding its content (a
recapture raced a removal), the entry is dropped from history and later
copies of it report `"unknown"`. An entry captured again since the copy was
asked for is kept.

The service starts `watch --owner-pid <shell pid>`. A watcher whose parent is
no longer the shell once its parent-death signal is armed exits without
starting `wl-paste`.

## Workbench

With a `model` construction property, the service takes its items from the
model, sends `copy`, `remove` and `clear` to it, and runs no helpers. A model
attached later stops every helper the service had started. The
workbench gives every fixture a clipboard model (see
`design-lab/fixtures/default.json`).
