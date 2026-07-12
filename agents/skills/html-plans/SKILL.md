---
name: html-plans
description: Publish plans, reports, and live implementation logs as hosted HTML pages via pagebin and return a URL - use when asked for an "html plan", a browsable report, a live implementation log, or to "publish with pagebin".
---

`pagebin` is installed on all fleet machines; auth comes from the
environment (`PAGEBIN_ENDPOINT`, `PAGEBIN_PUBLISH_TOKEN` via `~/.bashenv`).
Do not probe with `--help`.

## Authoring

- Write a self-contained single-file `.html` (inline CSS, no external
  requests) or a `.md` file — pagebin renders Markdown to dark-themed HTML
  with GFM tables, highlighting, and Mermaid.
- Throwaway plans go in the session scratchpad; reports and implementation
  logs that belong with the work go in the repo (e.g. `docs/<ticket>/`).
- Always use absolute file paths — the shell cwd resets between calls.
- Keep the default `--sandbox standard` (Markdown/Mermaid rendering needs
  it); use `--sandbox strict` only for pure static HTML that must be inert.

## Publish once, then update in place

```sh
pagebin publish /abs/path/plan.html --ttl 30d --json
```

Capture `id` and `url` from the JSON **immediately** and keep them for the
rest of the session (`list` cannot recover viewer URLs later; `reissue`
mints a new URL but revokes the shared one). All later revisions:

```sh
pagebin update <id-or-viewer-url> /abs/path/plan.html --json
```

Never re-`publish` a file that already has an artifact — it mints a second
URL and splits the audience. The viewer URL must stay stable.

## Live implementation logs

For "update it as you progress" workflows: publish first (get the stable
URL and hand it to the user up front), then either

- run the watcher somewhere persistent — a Bash `&` background dies with the
  tool call:

  ```sh
  tmux new-session -d -s pagebin-watch "pagebin watch <id> /abs/path/log.html"
  ```

  (verify with `pgrep -af 'pagebin watch'`; kill the session when done), or
- skip `watch` and run `pagebin update` at each milestone — equally good for
  checkpoint-style logs.

Log deviations from the plan under a "Deviations" section and keep going.

## Delivering

End with the viewer URL as a bold markdown link. For long-running jobs,
also send it via the notify skill: `discord-notify -t "<job> done" -s
success --url <viewer-url>`. Default TTLs: `30d` for plans/reports, `4w`
for long-lived logs.
