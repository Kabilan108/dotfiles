# Codex Remote

A small phone-friendly remote for the Raspberry Pi over Tailscale.

It provides:

- Jellyfin playback controls.
- Seek forward/backward and jump to adjacent episodes in the current season.
- Text-only Jellyfin browsing and search.
- A one-tap HDMI audio fix for the Pi.
- A prompt box that starts non-interactive `codex exec` jobs.
- A local bearer token on top of Tailscale access.

## Run

On `tleilax`, the Pi flake enables this as `systemd.services.tleilax-remote`.
Runtime state lives in `/var/lib/tleilax-remote`, including the bearer token and
Codex job logs.

Get the current service URL with:

```bash
ssh kabilan@tleilax 'printf "http://%s:8787/?token=%s\n" "$(tailscale ip -4 | head -n1)" "$(cat /var/lib/tleilax-remote/.remote-token)"'
```

For local development:

```bash
nix develop ./raspi -c ./raspi/remote/scripts/run-dev.sh
```

The server prints a Tailscale URL like:

```text
http://100.73.84.103:8787/?token=...
```

Open that URL from your phone while connected to Tailscale.

## Notes

This does not attach to an already-open ChatGPT conversation. The prompt box starts a new `codex exec` task on the Pi and shows its output when it finishes.
