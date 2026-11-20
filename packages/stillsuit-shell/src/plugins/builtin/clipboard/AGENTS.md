# Clipboard plugin notes

- Keep the read-back in `_writeDurably` in `Service.qml`. Quickshell's FileView reports a failed atomic commit (ENOSPC on flush) as saved, and the crash-safety rules in `README.md` (Removal) depend on knowing the history reached disk. Remove the read-back once FileView reports failed commits.
- After a failed save, reset the FileView path before the next write, as `_historyCacheStale` does. FileView keeps the text of a failed save as if it were on disk and skips a later save of the same text, so a retry would write nothing. Remove this once FileView stops caching failed text.
- Make every state change either restart `persistTimer` or write at once. `_flushNow` assumes the file is current unless that timer runs or a write failed, and skips the shutdown write otherwise.
- Do not restart `expiryTimer` on every commit; `_rearm` only pulls the wake earlier. Restarting it each time would starve expiry while copies keep arriving, since the delay is never shorter than 10 minutes.
