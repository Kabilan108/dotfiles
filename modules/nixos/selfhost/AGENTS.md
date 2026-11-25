# Selfhost notes

The permission model for these services is in `docs/security-hardening.md` ("Selfhost service permission model"). Library shares and accounts are in `docs/nas-network-policy.md` ("Media library").

## Blocky (`blocky.nix`)

- Keep the package patch that removes `api.RegisterOpenAPIEndpoints` and `configureDebugHandler`. Blocky's HTTP listener serves unauthenticated management and profiling routes, even on loopback. `--replace-fail` breaks the build when upstream changes those two lines, which is the cue to review the patch.
- Keep upstreams and `bootstrapDns` as DoH by IP literal. The host's own resolver may be Blocky, so Blocky can't depend on DNS to find its upstreams.
- Keep `before = lib.mkForce [ ]` and the ordering after `tailscaled.service`. The nixpkgs module orders Blocky before `nss-lookup.target` as an early-boot resolver, but this instance binds the node's Tailscale IP.
- Keep the `preStart` wait for the Tailscale address unbounded (`TimeoutStartSec = "infinity"`). Blocky is the fleet's DNS and tailscaled can take minutes to get its address after an outage, so waiting must never count as a failure; the start limit (5 in 120 s) is for a Blocky that starts and then dies.
- Keep stdout and stderr on null and the query log off. Blocky's `log.privacy` redaction preserves name lengths and isn't applied to every error. Turn output back on only while debugging.
- `LimitCORE=0` and `MemorySwapMax=0` are set on nginx and tailscaled as well as Blocky because Tailscale Serve and the nginx front both handle decrypted DoH messages. The limits apply to everything those two services do on the host.

## CPA (`cliproxyapi.nix`, `cpa-usage-front.nix`)

- The admin front forwards `/v8/management/`, `/v0/management/` and `GET /v1/models` because the pinned dashboard calls v8, probes v0 for old backends, and fills its model list card from `/v1/models`. Check those three again when bumping the panel.
- The models front returns 404 for `/v1/tunnel`. CPA 8.0.68 added that websocket relay under `/v1/`. Anyone with the shared inference key can join it as a client or a server, no client here uses it, and CPA has no setting to turn it off. When a CPA bump adds a route under a forwarded prefix, decide whether the front should block it.
- Bump CPA and `passthru.managementPanel` in `packages/cliproxyapi.nix` together. The panel is a separate release asset from the backend and the unit serves the pinned file, so the two can drift apart.
- Do not downgrade CPA below 8.0.46: Codex's Responses websocket through CPA needs it (upstream PR #46). CPA opens an upstream websocket only for Codex auth files that have `"websockets": true`, so set that flag on every Codex credential added.
- `cpa-usage-front` exists so sera never holds the management key; agents can edit sera's code. Keep its two answers filtered: CPA's `auth-files` response carries raw API keys and personal details, and `api-call` returns every upstream response header, cookies included.
- Keep `@chown` in `SystemCallFilter`. `yq -i` in preStart fchowns its temp file to the current owner, which `~@privileged` would otherwise block; without capabilities the call can't change owners anyway. `SystemCallErrorNumber=EPERM` makes any other filtered call fail instead of killing the gateway mid-session.
- Keep `AF_NETLINK` in `RestrictAddressFamilies`. Go's network interface lookups use it.
- preStart prepends the `thread_not_found` rule so it runs before any operator rule. A 404 "No thread state was found" from a Claude request is a fault in that request, not a reason to cool down the account, and a broader rule earlier in the list could match it first.
- preStart drops `fallbacks` from `claude-*` requests that carry `thread` because Anthropic rejects a request with both. Unthreaded calls keep their fallbacks.

## Hark (`hark.nix`)

- Keep server state (`/vault/userdata/hark-server`, user `hark`) apart from Android release material (`/vault/userdata/hark`, kabilan). The release keystore and signing properties are agenix secrets owned by kabilan because the hark repo's Android release script (scripts/android-build-release) runs as kabilan, and the split means a compromised server can't read the keystore. `downloadsDir` is 0755 kabilan for the same script: it writes the APKs, the service only reads them.
- `sqlite` is installed system-wide for manual online copies of the database: `sudo -u hark sqlite3 <db> ".backup <dest>"`.

## Library and Jellyfin (`library.nix`, `jellyfin.nix`)

- Keep `rsize` and `wsize` at 1 MiB on the sealed mounts. With `seal` the CIFS client encrypts each request in a buffer sized from them, and at the 4 MiB default that is an order-4 allocation, which failed under memory fragmentation mid-copy (ENOMEM on close).
- Keep `/library` mounted at boot, read-only and `hard`. While the NAS is away, reads wait instead of failing, so a Jellyfin library scan can't see files vanish.
- Keep Jellyfin's library at `/media`. Its database stores the `/media/...` paths from the old container, and keeping them valid preserves watch state and metadata.
- Keep `_netdev` on the `/media` bind. As a plain local bind it joined `local-fs.target`, which then waited on `/library` and the network, and systemd broke that cycle at boot by mounting `/library` before the network.

## Media acquisition (`media-arr.nix`, `mullvad-relays.nix`)

- Keep `qbittorrent` confined to the `torrent` network namespace with `bindsTo` and `partOf` on `torrent-netns.service`, plus `InaccessiblePaths` on `/run/nscd` and `/run/systemd/resolve`. The namespace holds only `lo` and `wg-torrent` with an `inet torrent` nftables drop policy, so a VPN drop fails closed instead of falling back to the host NIC, and blocking host resolver sockets prevents DNS leaks if the upstream unit ever permits `AF_UNIX`. The Web UI reaches host `127.0.0.1:8334` only through `qbittorrent-webui-proxy`.
- Keep `qbittorrent` out of `users`, its `UMask` at `0007`, and `/var/lib/qBittorrent/qBittorrent` at `0700`. `qbittorrent`, `radarr`, and `sonarr` share `media-dl` on `/vault/userdata/downloads` (`2775`), while `0700` keeps `radarr`, `sonarr`, and other host users out of qBittorrent's config and password hash. Only `radarr` and `sonarr` join `users` to write to `/library-rw`.
- Keep `settings.auth` pinned to `method = "Forms"` and `required = "Enabled"` on Prowlarr, Radarr, and Sonarr. Tailscale Serve and nginx proxy all requests from `127.0.0.1`, so `DisabledForLocalAddresses` or unset auth leaks API keys through `/initialize.json` to both tailnet clients and local host processes.
- Keep `/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf` seeded only when absent in `preStart` instead of setting `services.qbittorrent.serverConfig`. Setting `serverConfig` overwrites the file on every restart and wipes passwords or UI changes.
- Mullvad dropped port forwarding in 2023. Public well-seeded torrents work without it, though seeding is slower and rare low-seed or private-tracker torrents can stall. If stalls become an issue or private trackers are added, switch the WireGuard peer to a provider that supports WireGuard port forwarding, such as Proton VPN or AirVPN.
- `mullvad-relays.nix` holds public Mullvad New York WireGuard relay endpoints and public keys from `https://api.mullvad.net/www/relays/wireguard/`. Only the private key and tunnel address live in the `selfhost-torrent-wg-key` agenix secret.

## Siren (`siren.nix`)

- Change the Parakeet boost terms or weights only through a new evaluation. The current values come from the November 2026 dictation evaluation (~/.local/state/vocab-eval/report.md on jacurutu): the low first-token weight (0.05) keeps stray capitalisation down while later tokens still pull whole terms in.
- Keep `SSL_CERT_FILE` and `REQUESTS_CA_BUNDLE` on the system CA bundle. Siren's venv gets certifi from its `uv.lock`, so a CA distrust in NixOS (the October 2026 eMudhra compromise, for example) would not reach it on rebuild.
- `HF_TOKEN_PATH` points at a file that doesn't exist on purpose: `huggingface_hub` treats a missing token file as no token, so siren shares the model cache without kabilan's login. A gated model needs `HF_TOKEN` in `secrets/selfhost/siren-env.age`.
- Keep `m::rwX` in the tmpfiles ACL rule. Any `chmod 700` or `600` inside the cache zeroes the ACL mask and silently revokes siren's entry; tmpfiles restores it only on boot and switch.
