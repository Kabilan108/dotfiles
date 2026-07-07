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

## 5. Decisions queued for you (nothing blocks on them)

- **Agent workspace position**: the named "agent" workspace sits at idx 1 (top
  of the workspace list). If you'd rather not hit it first when cycling up,
  say so and it can be reordered/renamed.
- **Hot corners are now off** (`gestures { hot-corners { off; } }`): synthetic
  pointer sweeps through (0,0) kept popping the overview under agents. You
  still have Mod+O. Revert the config block if you miss the corner.
- **Electron CDP wrappers**: recipes.md #6 documents relaunching Discord/Slack
  with `--remote-debugging-port` for full background control. Opt-in only —
  say the word and `discord-agent`/`slack-agent` wrappers can be added to bin/.
- **ydotoold service** (codex-desktop module) is no longer needed by this
  skill (acu uses wlrctl/wtype/dotool, none need the daemon); Codex Desktop
  may still use it, so it was left untouched.
