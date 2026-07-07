# Worked recipes

Each recipe follows the contract: route first, see→act→verify, restore at the end.

## 1. Background research window (browser, fully invisible)

No desktop control needed at all — the helium agents instance exposes CDP on
9222 whenever it is running (start it with `helium-agents-devtools` if not):

```bash
curl -fsS 127.0.0.1:9222/json/version    # reachable? if not: helium-agents-devtools &
agent-browser open https://docs.example.com --new-tab
agent-browser snapshot                   # @refs for clicking/reading
```

The helium window can sit on any workspace; nothing you do via CDP touches focus.
Only use `acu` here to *show* the user something: `acu shot --app helium`.

## 2. Read a chat app without disturbing the user (Discord/Slack)

```bash
acu state                                    # find the window id
acu shot --window <id> -o /tmp/discord.png   # works even on hidden workspaces
# view the png; repeat as it updates — this is a read-only live camera
```

No focus change, no flicker, clipboard preserved.

## 3. Interact with a chat app (compose, click)

Prefer the semantic path — it needs no focus at all (recipe 9): `acu ui` to find
the composer and buttons, `acu act --set-text` to draft, `acu act` to press.
Requirement: the app must have been launched after the session's a11y flag
(current long-running instances may have dormant trees until relaunched).
Note: chat apps usually have MCP servers too — for Slack/Discord *content*
work, an MCP integration beats computer use entirely; use acu when the task is
about the app's UI itself.

Seat-input fallback (takes over the desktop briefly; batch it):

```bash
acu focus --app discord                # records previous focus
acu shot --app discord --grid          # ground your click targets
acu click --app discord --local 640,1360   # e.g. the message box
acu type "message text"                # verify BEFORE any Enter that sends
acu shot --app discord                 # verify the draft looks right
acu key Return                         # only if sending was requested
acu restore                            # back to where the user was
```

Either path: for unattended sending, stop after the draft shot and confirm with
the user unless they explicitly authorized sending.

## 4. Launch a GUI app for later, without stealing focus

```bash
acu spawn --bg -- nautilus                     # any app → "agent" workspace
acu spawn --bg -- ghostty --class=acu.build -e htop   # marked terminal: zero flicker
acu wait --app nautilus --timeout 15
acu shot --app nautilus                        # confirm it opened sanely
```

User pulls it over when ready: `nirius move-to-current-workspace --app-id nautilus`
(or workspace navigation — it's all one session).

## 5. Drive a terminal task (never click terminals)

```bash
tmux ls                                        # session per project
tmux new-session -d -s agent-task -c ~/proj
tmux send-keys -t agent-task 'just build' Enter
sleep 5; tmux capture-pane -t agent-task -p | tail -30   # verify output
```

If the user should see it: `acu spawn --bg -- ghostty --class=acu.task -e tmux attach -t agent-task`.

## 6. Relaunch an Electron app with CDP (opt-in, restarts the app)

Only with user approval — it restarts their app and exposes CDP on loopback:

```bash
pkill -x Discord && sleep 1
acu spawn --bg -- Discord --remote-debugging-port=9223
acu wait --app discord --timeout 30
agent-browser connect 9223                     # then drive it like a browser
```

## 7. Fill a small GUI dialog precisely

```bash
acu shot --window <id> --grid          # read coordinates off the grid overlay
acu click --window <id> --local 420,310
acu type "value"
acu key Tab; acu type "second field"
acu shot --window <id>                 # verify both fields before confirming
acu click --window <id> --local 500,480    # OK button
acu wait --gone <id> --timeout 5       # dialog closed = success signal
```

## 8. Recover a confused desktop

```bash
acu doctor                    # tells you what is wrong
niri msg action close-overview
acu focus --back              # or: acu focus --app <what the user had>
acu restore
```

## 9. Semantic (no-focus) interaction with an a11y-enabled app

Works for GTK/Qt apps and any Chromium/Electron app launched after the session's
screen-reader flag (or with --force-renderer-accessibility):

```bash
acu ui --app discord --find "message"        # elements: id, role, name, extents, actions
acu act --app discord 0.1.4.2 --set-text "draft"   # set editable text in-process
acu act --app discord 0.1.4.7                # press a button — no focus, no pointer
acu shot --app discord                       # verify pixels
```

Element ids are index paths valid only for the current UI state — re-run `acu ui`
after anything changes. If `acu ui` reports a dormant tree, the app predates the
flag: relaunch it (ask the user for their daily-driver apps).
