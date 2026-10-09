# Russ playlist sync

`bin/russ-playlist-sync` calls Executor's MCP endpoint directly with Python's standard library. Normal runs read a dedicated long-lived Executor API key through systemd `LoadCredential`. Agenix decrypts `secrets/executor/russ-playlist-sync.age` to `~/.config/russ-playlist-sync/executor-env` with mode 0600. The encrypted file contains one `EXECUTOR_API_KEY=...` assignment; the plaintext key is never committed. `--agent-auth` is a one-off setup option that reads a fresh saved Executor token without refreshing or modifying the agent's credentials. Spotify access stays inside Executor. There is no model invocation or T3 scheduled task.

The fixed target is [Tony's Russ playlist](https://open.spotify.com/playlist/42vFNy1x38EFtT05MfpGYs), and the fixed artist is [Russ](https://open.spotify.com/artist/1z7b1Pr1rSlvWRzsW3HOrS). Ownership is checked before every sync. The US catalog scan includes albums, singles and appearances, with each track checked for Russ's artist ID.

The first catch-up initially used July 10, 2026. Tony then requested the full catalog. Run `bin/russ-playlist-sync --catch-up-all --apply` once to include all releases and reconsider songs removed before that catch-up. Successful completion saves the full-catalog cutoff and the seen-song history. Later weekly runs preserve removals. The request is persisted before inventory starts. If authentication, rate limits or another failure interrupt the catch-up, later weekly runs retry the full catalog. The request clears only after every batch succeeds; removal history applies after that completion. The API key works, but Spotify currently returns HTTP 429 with reason `QUOTA_EXCEEDED` for the artist catalog endpoint, so the full catch-up remains pending.

Seen track IDs and normalized titles with credited artist IDs persist in `~/.local/state/russ-playlist-sync/state.json`. Album/single and clean/explicit editions with the same title and artists count as one song. Remixes with different titles can be added. Catalog reads are paced. A separate cache retains fetched album tracks so interrupted backfills can resume without downloading every album again. Weekly scans refresh the release list and fetch new albums or albums whose track count changed. Track substitutions that keep an existing album's ID and track count unchanged require clearing that album's cached tracks.

The Sietch user timer runs Saturday at 12:00 UTC with up to 30 minutes of random delay. `Persistent=true` catches up when the machine comes back after missing the scheduled time. The timer is enabled and active. Its current service reads the dedicated API key and runs the repository script. The Home Manager module and agenix declaration take over after the next user-managed rebuild; no rebuild was performed by the agent. Keep the state directory across reinstalls. Deleting it loses removal history.

```sh
# Read-only candidate scan
~/dotfiles/bin/russ-playlist-sync

# Run the installed service now
systemctl --user start russ-playlist-sync.service

# Inspect schedule and results
systemctl --user list-timers russ-playlist-sync.timer
journalctl --user -u russ-playlist-sync.service -n 30 --no-pager

# Disable automation
systemctl --user disable --now russ-playlist-sync.timer
```

Also set `home-manager.users.kabilan.dotfiles.services.russ-playlist-sync.enable = false` in Sietch's configuration before a later rebuild if disabling permanently.

The script records a pending batch before each Spotify add. If a write is interrupted, the next run checks whether the batch reached the playlist. If any pending song is absent, it stops with an error, since that could mean either a failed add or a deliberate removal. Inspect the playlist and journal before resolving this. To accept the uncertain songs as handled, add their `id:<track-id>` keys to `seen` and clear `pending` in the state file. Do not clear pending blindly and restart, as that could restore a removed song.

Verification at installation covered a live candidate scan, exact Home Manager service/timer evaluation, Ruff, ty, and isolated mock checks for duplicate editions, manual removals, delayed listings, dry-run behavior and interrupted writes. A second reader reviewed the state and retry behavior. The initial live add succeeded and a separate playlist read verified all three new tracks. A live transient systemd check verified that LoadCredential supplied the dedicated API key and Executor verified the playlist owner. The weekly timer is active. The full catch-up hit Spotify rate limits. Bounded 429 retries were observed; the isolated repeat-run and removal tests passed.

The active job and removal history were moved from Jacurutu to Sietch. Jacurutu's timer is disabled. Sietch has user lingering enabled, so its user timer runs without a desktop login.

Spotify `QUOTA_EXCEEDED` is a developer quota-bucket failure, distinct from ordinary short-window rate limiting. The same Executor credential still reads the owned playlist. These quota failures end the run after one call and retain the full catch-up request for the next weekly run. Other 429 responses retain bounded Retry-After retries. Spotify does not publish a reset time in its [quota documentation](https://developer.spotify.com/documentation/web-api/concepts/quota-modes).
