# Deploy notes

The trust model is in `docs/security-hardening.md` ("Binary cache", "Fleet tags and waiting for the cache"). `tests/test_deploy_gate.py` pins the tag format and the receiver; `tests/deploy-trigger.nix` pins the socket and broker.

## Signing and pushing

- Keep `unset SSH_AUTH_SOCK` in `deploy-tag sign`. ssh-keygen signs through any ssh-agent that lists the key, and GNOME Keyring's agent lists every `~/.ssh/*.pub` but can't ask for the YubiKey PIN. Without an agent, ssh-keygen loads the key handle file and asks for the PIN on the terminal.
- Add a deploy YubiKey as a new key made with `ssh-keygen -t ed25519-sk -O verify-required`, whose comment is its allowed-signers principal, plus its serial in `deploy.signerYubiKeys` in `lib/fleet.nix`. Do not reuse the touch-only login keys in `hosts.jacurutu.keys.human`: `requirePin` refuses signatures without the PIN flag.
- `deploy.pushKnownHosts` in `lib/fleet.nix` is GitHub's ed25519 host key from `gh api meta`. Refresh it from there if GitHub rotates the key; `deploy-tag push` uses `StrictHostKeyChecking=yes` against that file alone.
- In `deploy-key.sh`, trust only `ykman list`'s exit status and keep its stderr discarded. ykman logs every transport that fails (PC/SC without pcscd, for example) even when the FIDO HID interface then reads the serial, and that interface needs no PIN or touch.
- Keep `--no-pager` on every git call in `deploy.sh`. `deploy` asks for confirmation on the terminal, and a git pager would take the terminal and swallow the answer.

## Verifying tags

- Keep the explicit `return 1` and `return 0` in every check of `verify` in `deploy-tag.sh`. Callers run it as `if verify`, which turns errexit off inside the function, so a failed check without a return would fall through to the next one.
- `sk_signature_flags` follows the SSHSIG layout in OpenSSH's PROTOCOL.sshsig and PROTOCOL.u2f: it skips version, publickey, namespace, reserved and hash_algorithm, then reads the flags byte (0x01 touch, 0x04 PIN). ssh-keygen and `git verify-tag` check neither flag, so this parser is the only check. A new security-key type must be added to its list of accepted signature types.

## Receiver

- Never add `--no-write-lock-file` to the receiver's Nix commands. In Nix 2.34 it turns the refusal from `--no-update-lock-file` back into a warning, so a stale `flake.lock` would build. Check again on a Nix upgrade before adding it.
- Keep root's Nix and git in the receiver reading only store files and root-owned paths. `receiverNixConf` strips the system nix.conf's include lines because they name files outside the store (the access-token include, for one), and its directory has no registry, machines or netrc file; `HOME`, the XDG directories and the git config variables in the unit's environment close the other routes.
- The receiver builds in its state directory on purpose: the `result` link there keeps the built system from garbage collection between the build, which runs outside the switch lock, and the switch.
- Keep `restartIfChanged = false` and `X-StopOnRemoval = false` on `deploy-receiver.service`. The switch that the receiver runs must not stop or restart the receiver; nixos-upgrade does the same.
- The run record lives under `/run` because systemd job IDs restart at boot, so records from an earlier boot would name the wrong runs. `deploy-trigger` reads the record once more after its job disappears, because `run-record.sh` writes the exit line before the job ends.
