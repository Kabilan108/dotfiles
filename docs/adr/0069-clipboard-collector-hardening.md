# Clipboard collector treats its inputs as hostile and dies with its parent

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The collector runs under `wl-paste --watch`, reads offers from any Wayland client, and writes payloads into a state directory. Offer MIME types reach `wl-paste` argv. Files in the state directory could be replaced by something else. `/proc/<pid>/stat` puts the process name in parentheses, and that name may contain spaces or `)`. A payload collected after `wl-paste` exits has no consumer. A process group id can be reused once its leader is reaped. The QML clipboard service is a separate program that validates MIME types before asking for a copy and must recognise the collector's exit code for a missing blob.

## Decision

- `MIME_RE` accepts a MIME type or an X11-style atom such as `UTF8_STRING`, and never a string that starts with `-`, so a type cannot become a `wl-paste` flag. The model's `MIME_PATTERN` mirrors it, and the collector validates again before running wl-copy.
- `COPY_BLOB_GONE` (3) in the model mirrors the collector's `BLOB_GONE`: `copy` found the blob missing or not holding its content.
- `OPEN_READ` includes `O_NONBLOCK` so a planted FIFO cannot block the open; the `S_ISREG` check then rejects it.
- `_is_secret_source` treats an origin that fails to parse as secret.
- `watch` exports its pid in `STILLSUIT_CLIPBOARD_WATCH_PID`; `emit` arms `PR_SET_PDEATHSIG` with `SIGKILL` and then requires its parent to be a `wl-paste` whose parent is that pid. Once `wl-paste` is gone, no payload reaches disk.
- `_parent_and_comm` parses the fields after the last `)` in the stat line.
- The watch supervisor waits with `waitid(..., WEXITED | WNOWAIT)` and kills the group before reaping, so the group id cannot be reused first.
- The image MIME preference after `image/png` follows Omarchy's clipboard `capture.sh` (basecamp/omarchy, MIT License).

## Consequences

Each guard closes a specific path for a hostile client or a stale process to write clipboard data to disk. Removing one reopens that path. The MIME pattern rejects some legal but unusual types. The MIME pattern and the blob-gone exit code must change together in the model and the collector; the collector's own check remains the boundary.

## Where

- `packages/stillsuit-shell/bin/stillsuit-clipboard-collector` (`MIME_RE`, `BLOB_GONE`, `IMAGE_TYPES`, `WATCH_PID_ENV`, `OPEN_READ`, `_is_secret_source`, `_parent_and_comm`, `_started_by_watch`, `cmd_emit`, `cmd_watch`)
- `packages/stillsuit-shell/src/plugins/builtin/clipboard/ClipboardModel.js` (`MIME_PATTERN`, `COPY_BLOB_GONE`)
