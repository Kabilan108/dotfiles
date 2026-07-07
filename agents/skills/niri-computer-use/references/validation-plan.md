# Morning validation plan (post `sudo nixos-rebuild switch`)

Everything below already works live (tools resolved via nix-shell + cached store
paths); the rebuild just makes wlrctl/wev/dotool first-class in the profile so
the cache can't be GC'd away. Total time: ~3 minutes.

## 1. Rebuild

```bash
cd ~/dotfiles && sudo nixos-rebuild switch --flake .#jacurutu
```

Expected new home packages: `wlrctl`, `wev`, `dotool` (niri module).

## 2. Preflight

```bash
rm -f ~/.cache/acu/tools.json    # drop nix-shell-era paths; force profile paths
acu doctor                        # expect 0 failures, wlrctl from /etc/profiles/...
```

## 3. Input smoke test (30s)

```bash
acu state                              # sanity: workspaces + agent ws present
acu spawn --bg -- ghostty --class=acu.check -e bash
acu shot --app acu.check --grid        # verify: png path + 100px grid renders
acu focus --app acu.check
acu type 'echo hello' && acu key Return
acu shot --app acu.check               # verify: command + output visible
acu key mod+o && niri msg overview-state   # expect: Overview is open
acu key mod+o                              # ... and closed again
acu focus --back && acu restore
niri msg action close-window --id <acu.check id>
```

## 4. Click precision check (optional, 60s)

```bash
acu spawn --bg -- pavucontrol
acu shot --app pavucontrol --grid      # read a tab's coordinates off the grid
acu click --app pavucontrol --local <x>,<y>
acu shot --app pavucontrol             # verify the tab switched
niri msg action close-window --id <id>; acu restore
```

## 5. Decisions (resolved 2026-07-07)

- **Agent workspace position**: pinned to the bottom of the workspace list
  (`move-workspace-to-index 9 --reference agent`, applied live and at startup).
- **Stillsuit indicator**: the agent workspace renders as a mauve dot/pill in
  the TopBar workspace strip (`agentWorkspace` in TopBar.qml).
- **Hot corners stay off**; overview remains on Mod+O.
- **No Discord/Slack CDP wrappers**: their MCP servers are the better content
  channel; acu ui/act + seat fallback covers UI-level needs. The relaunch
  recipe (recipes.md #6) stays documented for one-off deep debugging.
- **ydotoold service** (codex-desktop module) is not needed by this skill;
  left untouched for Codex Desktop.
