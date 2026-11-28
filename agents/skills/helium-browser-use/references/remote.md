# browse from sietch

The browser and its relay run on jacurutu. `browse-relay-tunnel sietch`, run on jacurutu, copies jacurutu's relay token to sietch and holds a reverse SSH tunnel from sietch `127.0.0.1:19988` to jacurutu `127.0.0.1:19988` in tmux target `browse-relay:sietch`. sietch's `browse` is built with `OPENCODE_BROWSER_AUTOSTART=0`, so with the tunnel down it reports no relay instead of starting one.

Check from sietch:

```bash
curl -fsS http://127.0.0.1:19988/version
browse status
```

If that fails, the tunnel is down. Ask Tony to run `browse-relay-tunnel sietch` on jacurutu; don't start a relay or a browser on sietch.

Pages load from jacurutu's network, so `127.0.0.1` in a URL means jacurutu. Use sietch's tailnet name for its dev servers (`http://sietch:<port>`). File paths for uploads resolve on jacurutu: pass sietch files inline (`{ name, data }`, up to about 10 MB per call).

Agents on jacurutu and sietch share the one relay and the one browser, so other agents' tabs may be open alongside yours.
