# Docs notes

## tailscale-policy.jsonc

- The Tailscale admin console holds the live policy and this file is the repository copy. Change the console first, then copy the change here, and update the `tests` block with it: a grant that breaks a test fails the save.
- sietch is tagged `tag:server`, so the `autogroup:member` grants and the `autogroup:self` SSH rule do not cover it. It has its own short service grant because its consumers use the svc names too (dictator calls siren); add a service there only when something on sietch needs it.
- Keep `svc:cliproxyapi` out of the `autogroup:member` grant. Only jacurutu, sietch and agent boxes send inference.
- sietch may open any TCP port on the Pixel and nothing else there, because wireless ADB uses randomized pairing and connection ports.
- Away from home, jacurutu reaches tleilax's boot-time unlock through sietch over the LAN. This policy does not govern that path, so the sietch-to-tleilax denial here does not block it.
- `tag:grokbot` exists so Grokbot, which joins through a Tailscale OAuth app, leaves `autogroup:member` and gets only its own grant. Its sietch:443 access is Tailscale Serve on the machine's own HTTPS address, which carries the T3 MCP.
- `tag:kvm` isolates hardware IP-KVMs (`sietch-kvm`) from `tag:server`, `tag:credentials`, and `tag:grokbot` and prevents the KVM from initiating tailnet connections, while granting `autogroup:member` HTTP/HTTPS and WebRTC UDP access.
