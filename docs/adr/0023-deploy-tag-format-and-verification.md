# Deploy tags are accepted only in one strict, fully signed format

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

- `git verify-tag` checks the last signature block of a tag object. It accepts a tag whose message carries a second signature block, and a tag with text appended after the signature, which neither git nor ssh-keygen covers.
- ssh-keygen and `git verify-tag` don't check a security-key signature's touch and PIN flags.
- Fleet tags carry their fields (`Hosts:`, `Allow-Rollback: yes`) in the first paragraph of the signed message. A line of only spaces, tabs or Unicode spaces looks blank to a reader but doesn't end a paragraph for a parser that stops at the first empty line.
- `deploy` appends a commit list after the first paragraph. A carriage return in a commit subject would make the tag invalid.
- Callers use `if verify`, which turns off errexit inside the function.
- The deploy gate tests sign tags with OpenSSH's test-only software security key (`tests/sk-dummy.nix`, built from `regress/misc/sk-dummy`) in place of a YubiKey. Its signatures carry whatever touch and PIN flags the key file asks for. `ps -o ppid=` pads PIDs under seven digits with a space, which `ps -p` rejects.

## Decision

- `verify` accepts only an annotated tag named `deploy/<host>/<YYYYMMDDTHHMMSSZ>` that points at a commit, whose embedded name matches its ref, with exactly one signature block of any kind, which must be SSH, nothing but whitespace after `-----END SSH SIGNATURE-----`, no carriage return, and no line of only whitespace (a non-empty line needs a printable ASCII character). A fleet tag needs exactly one `Hosts:` line in its first paragraph, naming valid hosts other than `fleet`. The signer must be in `DEPLOY_SIGNERS`.
- With `DEPLOY_REQUIRE_TOUCH` and `DEPLOY_REQUIRE_PIN`, `sk_signature_flags` parses the armored signature using the layout in OpenSSH's PROTOCOL.sshsig and PROTOCOL.u2f. It skips the version, publickey, namespace, reserved and hash_algorithm fields, accepts only `sk-ssh-ed25519@openssh.com`, `sk-ecdsa-sha2-nistp256@openssh.com` and `webauthn-sk-ecdsa-sha2-nistp256@openssh.com`, and reads the flags byte: 0x01 for touch, 0x04 for PIN.
- The first paragraph ends at the first empty line. `Allow-Rollback: yes` counts only there, where `deploy` writes it; the commit list after it can't produce the line. `deploy` strips carriage returns from that list.
- Every check in `verify` returns explicitly.
- The deploy module asserts that every key in `deploy.signers` is a security key (`sk-`), since only those signatures carry touch and PIN flags.
- `test_second_signature_block` asserts that `git verify-tag` accepts a tag with a second signature block and that the receiver refuses it ("it needs exactly one SSH signature"). `test_unsigned_trailer_cannot_allow_a_rollback` asserts that `git verify-tag` accepts an `Allow-Rollback` trailer appended after the signature and that the receiver still refuses the rollback. The kill helper in `test_a_run_that_leaves_no_result_is_a_failure` strips spaces from `ps` output before passing it to `ps -p`.

## Consequences

- A software key can't become a signer: evaluation fails.
- Any new signed field must sit in the first paragraph, and any change to the message layout has to keep the no-whitespace-line rule.
- The flags parser depends on the SSHSIG format; a new key type needs adding to its list.
- The receiver's own message parsing must stay; relying on `git verify-tag` alone would accept these forged tags.

## Where

- `modules/nixos/deploy/deploy-tag.sh` (`verify`, `sk_signature_flags`, `signed_message`, `first_paragraph`, `hosts_line_ok`, `allows_rollback`)
- `modules/nixos/deploy/default.nix` (`assertions` on `deploy.signers`)
- `modules/nixos/deploy/deploy.sh` (tag message construction)
- `tests/sk-dummy.nix`
- `tests/test_deploy_gate.py` (`test_second_signature_block`, `test_unsigned_trailer_cannot_allow_a_rollback`, `test_a_run_that_leaves_no_result_is_a_failure`)
