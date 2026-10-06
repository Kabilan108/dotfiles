# Stillsuit launcher: implementation spec

Companion to `stillsuit-launcher-plan.html` (the approved plan). This file is the
contract shared by every implementation worker and reviewer. Where it disagrees
with the plan, this file wins.

## Decisions from the user (2026-10-05)

- Replace Walker and Elephant on niri. Hyprland sessions keep Walker and
  Elephant: the Hyprland compositor module imports them, and their units are
  gated on `XDG_CURRENT_DESKTOP=Hyprland` because sietch runs both compositors.
  Elephant's launch prefix changes so apps it starts land in their own scope.
- Full niri cutover in this PR: Mod+D, Mod+Tab, Mod+Shift+E, Mod+Alt+P and
  Mod+V open Stillsuit modes. No trial key.
- Prefix modes kept: `/` files, `@` web, `$` windows, `:` clipboard. Dropped:
  `;` provider list, `>` runner, `.` symbols. Calc stays in combi.
- Clipboard history: items expire after a configurable TTL (default 72 hours),
  200 items max. Skip password-manager copies. The user copies secrets from the
  Bitwarden extension in Helium and in Zen, and sometimes the web vault.

## Ground rules (from the existing host contract)

- Plugins never receive a generic command runner. Payload JSON never becomes
  argv, QML source, a file path or a shell command. New capabilities are named
  methods on `context.actions` with fixed argv shapes.
- Plugin services may run fixed, Nix-provided helper paths from their settings
  with `Quickshell.Io.Process` (the existing workflows/agent-usage pattern).
- Preserve PR #20's performance architecture: no idle polling, no per-event
  rebuilds of delegate lists, no `ScriptModel` with `objectProp` over rows that
  can be removed mid-list (see `docs/host-contract.md`, the Quickshell 0.3.1
  ScriptModel quirk). Hidden surfaces compute nothing. Gate timers on
  visibility. Prefer event APIs over polling.
- One exception, added after VM measurement: the launcher runs a single
  warmup about 2 s after the shell starts (app snapshot, `engine.prepare`,
  history read, icon-theme lookups for the top empty-query rows, one per
  event-loop turn). Cold icon lookups cost ~200 ms each and made the first
  Mod+D after login take ~1 s; with the warmup it takes ~64 ms. Nothing
  recurs.
- JS logic lives in plain JS files that work both as QML imports and in node
  (`if (typeof module !== "undefined") module.exports = {...}` at the bottom,
  as in `src/services/NotificationModel.js`). No `.pragma library` needed.
- Comments: only where they explain why. No commented-out code.

## Phase 0: core (needs a Home Manager rebuild to go live)

### Menu hosting

`src/core/MenuHost.qml`: one per output, created next to `PanelHost` in
`src/core/PanelHosts.qml`. It is a `PanelWindow` that stays mapped (Omarchy's
`shell/Ui/OverlayWindow.qml` at
`~/.agents/vendored-deps/basecamp/omarchy`): closed, it parks as 1x1 on
`WlrLayer.Bottom`, empty input mask, `WlrKeyboardFocus.None`, content hidden.
Shown: anchored to all edges, `WlrLayer.Overlay`,
`WlrKeyboardFocus.Exclusive`, a dim scrim from theme semantic colors, content
horizontally centered with its top at about 22% of the output height, and
`exclusionMode: ExclusionMode.Ignore`. Content is drawn only once the surface
has grown past 1x1.

API mirrors `PanelHost`: `present(item)`, `dismiss(item)`, `menuContent`.
Escape and a press outside the content close the menu through the router.
Focus goes to the content on present (the content forwards it to its text
field).

Menu content contract (document in `docs/host-contract.md`): an `Item` with
`readonly property bool hostedMenu: true`, `implicitWidth`, `implicitHeight`,
`open(payloadJson)` and `close()`. Like panels it does not create windows.

`SurfaceRouter` changes:

- `registerMenuHost(outputId, host)` / `unregisterMenuHost`.
- `_deliverOne`: a `hostedMenu` instance is presented in the placed output's
  `MenuHost`. Opening a menu dismisses open panels. Opening a panel or another
  menu closes the open menu. Track it as `presentedMenuId`.
- `_invokeClose` and `_destroyInstances` dismiss hosted menus from their host.
- `interruptForBanner` must not close a hosted menu (a notification arriving
  while you type must not close the launcher).
- `dismissPanels()` keeps its current meaning (panels). Menus close through
  `close(id)`, Escape, outside press, or a focused-output change.

### App launching and other new actions

A Nix helper `stillsuit-app-launch` (new file
`packages/stillsuit-shell/app-launch-helper.nix`, `writeShellApplication` with
`systemd`, `jq`, `coreutils` runtime inputs):

```
stillsuit-app-launch --name <label> [--cwd <dir>] -- <argv...>
```

1. Sanitizes `<label>` to `[a-zA-Z0-9_.-]`, max 64 chars, and appends a random
   suffix: unit `app-stillsuit-<label>-<rand>.scope`.
2. Replaces its environment with the systemd user manager's environment
   (`busctl --user --json=short get-property org.freedesktop.systemd1
   /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager Environment`,
   NUL-safe parse), because `stillsuit-shell.service` runs with an exact,
   minimal `PATH`. Launched apps must see the session's real `PATH` and
   `XDG_DATA_DIRS`.
3. `cd` to `--cwd` if it is an existing directory, else `$HOME`.
4. `exec systemd-run --user --scope --collect --quiet --slice=app.slice
   --unit=<unit> -- <argv...>`.

The shell runs it with `Quickshell.execDetached`. Result: the app's cgroup is
`app.slice/app-stillsuit-<label>-<rand>.scope`, never `stillsuit-shell.service`.

Nix options in `modules/home/stillsuit/options.nix` (wired in `service.nix`):
`programs.stillsuitShell.launch` with

- `terminal`: argv prefix for `Terminal=true` entries, default
  `[ "ghostty" "-e" ]`.
- `browser`: argv prefix for URLs, default `[ "xdg-open" ]`.
- `opener`: argv prefix for paths, default `[ "xdg-open" ]`.
- `session.{lock,suspend,logout,reboot,poweroff}`: argv lists.

The service gets `STILLSUIT_APP_LAUNCH_HELPER` (helper path) and
`STILLSUIT_LAUNCH_CONFIG` (a JSON file of the `launch` option). Add
`wl-clipboard` to the service's exact runtime inputs.

New core QML: `src/services/AppLaunch.qml` (module `Stillsuit.Services`). It
reads the launch config once at startup. New `context.actions` methods (also
on `IpcFacade` as plain functions, but NOT exposed through any `IpcHandler`:
IPC must not become an exec surface; document this exception):

| Method | Returns | Behavior |
|---|---|---|
| `appLaunch(desktopId, actionId)` | `ok`, `unknown`, `error` | Re-resolves `desktopId` in `DesktopEntries` (never trusts caller argv). `actionId` "" means the main entry. Uses the entry's parsed `command` (field codes already stripped by Quickshell), wraps `runInTerminal` entries in `launch.terminal`, `--cwd` from `workingDirectory`. |
| `openUrl(url)` | `ok`, `invalid`, `error` | Only `http:` and `https:` URLs, max 8 KiB. `launch.browser` + url. |
| `openPath(path, mode)` | `ok`, `invalid`, `error` | Absolute, existing-or-not path, no NUL. `mode` `open` opens it, `reveal` opens its parent directory. `launch.opener` + path. |
| `copyText(text)` | `ok`, `error` | `wl-copy` with the text on stdin (never argv). Max 1 MiB. |
| `sessionAction(name)` | `ok`, `unknown`, `error` | `lock`, `suspend`, `logout`, `reboot`, `poweroff`, argv from `launch.session`. Runs detached, not in an app scope. |

Every launch passes through the helper. `DesktopEntries` rescans happen in
Quickshell; `AppLaunch` does not poll.

### UI primitives (`src/ui`, add to `qmldir`)

- `ShellTextField.qml`: themed single-line input (placeholder, caret, selection
  colors from theme semantics, `text`, `placeholderText`, `accepted()`,
  forwards `Keys` so a parent can handle Up/Down/Tab/Enter). No vim-style
  key capture.
- `ShellAppIcon.qml`: an icon by freedesktop name or absolute path via
  `Quickshell.iconPath(name, true)` with a themed fallback glyph when the
  lookup fails. Asynchronous image loading, `sourceSize` set to the display
  size.

### Docs and tests

- `docs/host-contract.md`: menu kind hosting, the new actions, why they are not
  on IPC.
- `.agents/skills/stillsuit-plugin/references/` (contract.md, primitives.md)
  contract and primitives: add the same.
- Headless fixture coverage for the router's menu branch (present, dismiss
  panels on open, banner does not close menu, close on Escape path) and for the
  helper's argv shape and unit naming (a bash test that stubs `systemd-run` and
  `busctl` on PATH).

## Phase 1-2: `stillsuit.launcher` plugin (hot-reloads)

Directory `src/plugins/builtin/launcher/`. Manifest: kinds `service` and
`menu`, `scope.menu: "global"`, `keepLoaded: true`, dependencies
`["stillsuit.clipboard"]`. The host has no optional dependencies, so the
clipboard service must construct even when its runtime pieces fail (missing
`wl-paste`, unwritable state dir): it reports that through its own `status`
and `error` properties instead of failing construction, so a clipboard problem
never takes the launcher down.

IPC payload (through the existing `stillsuit-surface open|toggle`):

```json
{ "mode": "combi" | "windows" | "power" | "profiles" | "clipboard", "query": "" }
```

Unknown or missing mode means `combi`. Toggle on an open launcher in a
different mode switches mode instead of closing.

### Pure-JS model (`src/plugins/builtin/launcher/model/`)

- `Matcher.js`: `score(query, fields, opts)` -> `{score, field, positions}`.
  fzf-v2-style subsequence scoring (bonuses: string start, word boundary,
  camelCase, consecutive run; penalties: gaps, late start), case-insensitive
  with a bonus for case match. Field index penalty `min(index*5, 50)`.
  Acronym match for terms of 5 chars or fewer ("vsc" -> Visual Studio Code).
  Returns 0 for no match.
- `History.js`: Elephant's `CalcUsageScore` port. Per `(query, itemKey)`
  record `{count<=10, lastUsed}`; boost `max((10 - days) * count, 1)` divided
  by `1 + |storedQuery.length - query.length|`, applied only after an item
  passes the minimum score. Also an empty-query ordering: items by recency and
  frequency. Serialize/deserialize a versioned JSON object; bound to 2,000
  records, oldest evicted.
- `Query.js`: parses raw input into `{provider ids, text, prefix}` using the
  prefix table `/ files`, `@ web`, `$ windows`, `: clipboard`, and the mode
  table: `combi` -> apps, calc, web (web only as a trailing fallback row);
  `windows` -> windows; `power` -> power; `profiles` -> profiles;
  `clipboard` -> clipboard. A prefix overrides the mode. Empty combi query ->
  apps ordered by usage history.
- `providers/*.js`, each exporting `{ meta: {id, label, icon}, query(text,
  env) -> rows, activate(row, actionId) -> intent }`. `env` carries snapshots
  (apps, windows, profiles, clipboard items, files results, calc result), the
  matcher, history and settings; providers never do IO.
  - `apps`: name, generic name, keywords, comment fields. Desktop actions as
    secondary actions. Hidden/NoDisplay already filtered by Quickshell.
  - `calc`: shows the async `qalc` answer row for the current query when the
    query looks like math; Enter copies the result.
  - `web`: one row "Search the web for <text>" using the engine URL template
    (Unduck `https://unduck.link?q=%TERM%`); bare URLs (`example.com`,
    `https://...`) get an "Open <url>" row.
  - `windows`: niri windows from `context.compositor.windows`, most recently
    focused first (`focus_timestamp`), title + app id, workspace in subtext.
  - `power`: lock, suspend, logout, reboot, poweroff with keywords.
  - `profiles`: from `context.profiles.available`, current one marked.
  - `files`: rows from async `fd` results; actions open / reveal / copy path.
  - `clipboard`: rows from the clipboard service; actions copy, remove,
    clear all; preview text or image path.
- Row shape: `{ key, provider, text, subtext, icon, score, positions,
  actions: [{id, label}], preview?: {kind: "text"|"image", text?, path?},
  current?: bool }`. `key` is stable per item and unique within a result set.
- Intents (the only things `activate` returns):

```text
app.launch      {desktopId, actionId?}
window.focus    {id}
session         {action: lock|suspend|logout|reboot|poweroff}
profile.activate {id}
url.open        {url}
text.copy       {text}
path.open       {path}   path.reveal {path}
clipboard.copy  {id}     clipboard.remove {id}   clipboard.clear {}
```

  An intent may set `keepOpen: true` (clipboard.remove). Results are sorted
  by score descending then text, capped at 100.

Node tests in `src/tests/launcher/` (run by a `run.sh` that exits non-zero on
any failure), including the plan's table: `ghost` -> Ghostty first; `obs`
after three Obsidian launches -> Obsidian above OBS Studio; `vsc` -> Visual
Studio Code; `2+2*3` -> calc row on top once the answer arrives, stale answers
dropped; `@nix flake` -> web only; `$hel` -> Helium windows, most recent
first; empty combi -> apps by usage; prefixes stripped correctly; a 1,500-app
synthetic set scores a keystroke in under 8 ms of JS.

### QML

- `Service.qml` (global service): owns the app snapshot (from
  `DesktopEntries.applications`, rebuilt on its change signal only, debounced
  750 ms), history file `<stateRoot>/launcher/history.v1.json` (atomic write,
  debounced), the async `qalc` and `fd` processes with a generation counter
  (stale replies dropped; `fd` debounced ~120 ms, `qalc` ~60 ms, both killed
  when superseded or when the menu closes), and intent execution through
  `context.actions`. For `window.focus` it closes the surface first and focuses
  on the next event-loop turn. Exposes `results` (array of row objects),
  `selectedIndex`, `mode`, `query`, `setQuery(text)`, `activate(index,
  actionId)`, `open(payload)`, `close()`.
- `Menu.qml` (hostedMenu content): search field (`ShellTextField`), mode chip,
  result list (`ListView` with `reuseItems: true` over an index model or keyed
  rows; never `ScriptModel` with `objectProp` over removable rows), preview
  pane in clipboard mode, a hint bar with the selected row's actions.
  Keys: Up/Down/Ctrl+J/Ctrl+K move, Enter activates the default action,
  Ctrl+Enter / Tab cycles secondary actions (show which), Escape closes,
  Ctrl+D removes in clipboard mode. Mouse: click activates, hover selects.
  Width about 640 px (clipboard about 960 px with preview), max 8.5 visible
  rows. Theme everything from `context.theme`.
- Settings (Nix): `qalcPath`, `fdPath`, `searchRoot` (default home),
  `webEngine` URL template, `maxResults` 100.

## Phase 3: `stillsuit.clipboard` plugin (hot-reloads)

Service-only plugin. A Nix helper collector runs under `wl-paste --watch`
(one watcher for text, one for images, or one with type inspection: worker's
choice, justified). Per change it:

1. Lists offered MIME types. Skips the copy when the offer includes
   `x-kde-passwordManagerHint` (value `secret`), or matches the password
   rules from the Bitwarden research (see the research notes appended below
   when available).
2. Writes the payload to a content-addressed blob
   `<stateRoot>/clipboard/blobs/<sha256>` (dir 0700, files 0600), and prints
   one JSON line event on stdout (`{"kind":"text"|"image", "sha", "mime",
   "bytes", "preview"}`; text preview truncated to 2 KiB).

The QML service is the single writer of `<stateRoot>/clipboard/history.v1.json`
(atomic, debounced): dedupe by sha (a repeat moves to the top), cap
`maxItems` (200), expire after `ttlHours` (72) with pruning at startup, on
insert, and on a coarse jittered timer (no tighter than 10 minutes), deleting
orphan blobs. API for the launcher: `items` (newest first), `revision`,
`copy(id)` (re-copy with the original MIME through a fixed argv, moves to
top), `remove(id)`, `clear()`. Images previewed from the blob path.

## Phase 4: Nix and cutover

- `home/desktop/wayland/quickshell/default.nix`: add the two plugins with
  settings, runtime inputs (`libqalculate`, `fd`, `wl-clipboard`, helpers),
  and the `launch` option values (`terminal` ghostty, `browser` helium,
  session commands incl. `lock-screen` and `niri msg action quit
  --skip-confirmation`).
- `home/desktop/wayland/compositors/niri/config.kdl`: the five binds call
  `qs ipc -c <configId> call stillsuit-surface toggle stillsuit.launcher
  '{"mode":"..."}'`. Run `niri validate`.
- `home/desktop/wayland/compositors/hyprland/default.nix`: import `walker.nix`
  and add `walker` and `elephant` to the Hyprland-session-only units.
  In `walker.nix`, set Elephant's launch prefix to an app-scope `systemd-run`
  and drop the Stillsuit profiles menu (Stillsuit doesn't run on Hyprland).
- `AGENTS.md`: update the Walker/Elephant note.

## Clipboard secret detection (research notes, 2026-10-05)

Sources read: bitwarden/clients 245879a5, chromium b5c392dd, firefox
b4b9efb6, arboard 3.6.1.

- Bitwarden desktop app sets `x-kde-passwordManagerHint: secret`. Firefox sets
  it only for private-browsing copies. Browser extensions cannot set it.
- Chromium (Helium) offers `chromium/x-source-url` = the main-frame URL of the
  copying context on every renderer text write. Bitwarden's Chromium extension
  copies from its offscreen document or popup:
  `chrome-extension://nngceckbapebfimnlniiiahkandclblb/...`. The web vault
  copy carries the vault page URL (`https://vault.sole-pierce.ts.net/...`).
  Not yet verified on Helium specifically: check with `wl-paste --list-types`.
- Firefox (Zen) offers `text/x-moz-url-priv` = the page origin for web pages
  (so the web vault is identifiable). Extension and address-bar copies omit
  it entirely (VM probe, Firefox 157, Bitwarden 2026.9.3).
- Bitwarden's extension "Clear clipboard" defaults to 5 minutes. When it fires
  it reads the clipboard first and only clears if it still holds the copied
  value. It writes `"\u0000"` on Chromium-family browsers and `""` on Firefox
  (`" "` in the legacy fallback). The web vault never clears.

Rules, in order:

1. Skip any offer containing `x-kde-passwordManagerHint`.
2. Skip when `chromium/x-source-url` starts with a configured secret source
   prefix (`secretSourcePrefixes`, default
   `chrome-extension://nngceckbapebfimnlniiiahkandclblb/` and
   `https://vault.sole-pierce.ts.net`).
3. Skip when `text/x-moz-url-priv` starts with a secret source prefix.
4. Clear correlation: a text offer whose content is exactly `""`, `"\u0000"`
   or `" "` is never recorded. It is a clear only in `unattributedFirefox =
   "record"` mode and only when the offer has the unattributed Gecko shape of
   rule 5 (Firefox's Bitwarden clear); a clear purges the newest entry if it
   is text, younger than `clearPurgeWindowSec` (default 330), and was captured
   from an offer with the same type list. Any other empty, NUL or space text,
   such as a failed sender's zero bytes, is skipped as empty and purges
   nothing.
5. Unattributed Gecko copies (decided after the VM probe, 2026-10-05): a
   Bitwarden-in-Firefox/Zen extension copy and a Firefox address-bar copy offer
   identical types with no source marker (`SAVE_TARGETS`, `COMPOUND_TEXT`,
   `text/plain;charset=utf-8` twice, no `text/x-moz-url-priv`). GTK3 apps
   offer the same shape, so for that shape only, the collector reads niri's
   window list before the payload read and after the last one. It records the
   copy only when both show the same focused window, with the same stamp, not
   matching `geckoAppIds` (Zen, Firefox, LibreWolf), and settled: stamped by
   niri (its 750 ms debounce), the newest stamp, and at least `focusSettleMs`
   (2 s) old. Anything else, including a failed lookup, skips. Cost:
   Zen/Firefox address-bar copies and GTK3 copies made within 2 s of a focus
   change (or before niri stamps the focus) don't enter history. Every text
   copy whose classification takes over 1 s (normally 20-40 ms; 250-280 ms
   in a VM encoding a recording in software) is skipped, because separate
   `wl-paste` calls can't be tied to one offer. Residual: within that window,
   a clipboard that flips between a benign offer and the secret more than
   once, or a mouse-only browser visit (in, copy, out) under niri's 750 ms
   debounce that niri never stamps. Both need several deliberate actions in
   under a second.
   `unattributedFirefox = "record"` turns the rule off and relies on rule 4.
   Chromium's clear write offers no text type at all.

The collector never logs clipboard content. Copies matched by these rules
are skipped before anything is written, subject to the timing residual in
rule 5.
