# Clipboard handling follows the 2026-10-05 probe of browser offers and skips copies it cannot attribute

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

A Wayland probe on 2026-10-05 recorded exact `wl-paste --list-types` output, duplicates and order kept, from Firefox 157, Chromium 154 and the Bitwarden extension 2026.9.3 (vault origin `https://localhost:8222`). Observed behaviour the collector and model depend on:

- Both browsers announce a clear with `CLIPBOARD_STATE=nil` before the data event.
- Firefox in record mode emits: copy, nil, duplicate data, nil, then the extension's zero-byte clear. The extension's clear offers the same type list as its copy.
- Gecko offers a GTK3-shaped type list. Qt, foot and wl-copy text offers never have that shape.
- Zen/Firefox address-bar copies offer exactly what the extension's password copy offers.
- When a second wl-copy sender fails, `wl-paste` still exits 0 with zero bytes.
- Without `--type`, `wl-copy` infers a binary type for a lone NUL.

The collector attributes Gecko-shaped copies by sampling niri's window list. niri stamps a refocused window only after its recent-windows debounce (750 ms); until then the focused window keeps its old stamp and the previously focused browser's stamp is the newest. A mouse-only visit to Zen commits no niri stamp at all, so two samples can agree while a stalled payload read returned the browser's copy.

## Decision

- Only Firefox's Bitwarden clear needs a purge, and it is Gecko-shaped. The model purges on a clear only when its shape (the collector's sha256 prefix of the offered type list) matches the newest capture's. Empty, NUL or space text from any non-Gecko offer, or from a failed transfer, is a plain empty skip, never a clear. A nil announcement neither purges nor detaches the following clear.
- In the default `--unattributed-firefox=skip` mode, unattributed Gecko-shaped copies are skipped; the accepted cost is that address-bar copies are skipped too.
- A focus that niri has not yet committed counts as unsettled, and the copy is skipped as unattributed. Stalled reads between identical samples are also skipped.
- Tests use the probed type lists verbatim (`FIREFOX_PLAIN`, `CHROMIUM_*`, `QT_TEXT`, `FOOT_TEXT`, `WL_COPY_TEXT`), and the QML fixture replays the probe sequence in skip and record modes. Collector tests cover the debounce window and the mouse-only visit with stalled reads. The headless e2e passes `--type` to wl-copy for its NUL case.

## Consequences

New browser or extension versions can change the type lists; a fresh probe should replace the constants rather than editing them by guess. Address-bar copies stay out of history unless record mode is chosen. Some legitimate copies made right after a focus change are skipped. If niri changes its debounce or starts stamping pointer focus, the settle logic and these tests need revisiting.

## Where

- `packages/stillsuit-shell/bin/stillsuit-clipboard-collector` (focus sampling, `--focus-settle-ms`)
- `packages/stillsuit-shell/src/plugins/builtin/clipboard` (model clear handling)
- `packages/stillsuit-shell/src/tests/clipboard/collector_test.py` (probe constants, clear and address-bar tests, `test_stalled_reads_between_identical_samples_are_skipped`, `test_switch_away_from_zen_inside_niris_debounce_is_skipped`)
- `packages/stillsuit-shell/src/tests/clipboard/model.test.js` (clear correlation)
- `packages/stillsuit-shell/src/tests/clipboard/e2e-headless.sh` (NUL case)
