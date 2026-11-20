# Siren shares the model cache anonymously, trusts the system CA store and boosts measured vocabulary

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

- Parakeet accepts a boost list. Terms and weights come from the Nov 2026 dictation evaluation (`~/.local/state/vocab-eval/report.md` on jacurutu): a low first-token weight keeps stray capitalisation down while later tokens still pull whole terms in.
- Siren's venv gets certifi from its `uv.lock`, so CA distrusts in NixOS (for example the Oct 2026 eMudhra compromise) wouldn't reach it on rebuild.
- Siren's models are public. `huggingface_hub` treats a missing token file as no token.
- The cache `/vault/userdata/huggingface` is owned by kabilan. Any `chmod 700` or `600` inside it zeroes the ACL mask, which silently revokes siren's entry.

## Decision

- `SIREN_PARAKEET_BOOST_TERMS` holds the evaluated term list, with `SIREN_PARAKEET_BOOST_CONTEXT_SCORE=0.05`, `SIREN_PARAKEET_BOOST_DEPTH_SCALING=40.0` and `SIREN_PARAKEET_BOOST_ALPHA=1.0`, as the default for requests without a `vocabulary` field.
- `SSL_CERT_FILE` and `REQUESTS_CA_BUNDLE` point at `/etc/ssl/certs/ca-certificates.crt`.
- `HF_TOKEN_PATH` points at `/var/lib/siren/hf-token`, which doesn't exist, so siren shares the model cache but not kabilan's login.
- A tmpfiles `A+` rule grants `u:siren:rwX`, the default `d:u:siren:rwX` so new files inherit it, and `m::rwX` to restore the mask. tmpfiles reapplies it on boot and switch.

## Consequences

- A gated model needs `HF_TOKEN` in `siren-env.age`.
- Changing the boost terms or weights should go through the evaluation again.
- Between switches, a stray chmod can still revoke siren's access until the next boot or switch.

## Where

- `modules/nixos/selfhost/siren.nix` (`systemd.services.siren.environment`, `systemd.tmpfiles.rules`)
