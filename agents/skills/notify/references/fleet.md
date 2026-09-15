# Fleet credentials and integration provisioning

Sietch and jacurutu use the same `harkctl` commands. The dotfiles flake selects
the machine credential at activation:

| Purpose | Runtime path | Encrypted source under `~/dotfiles` |
| --- | --- | --- |
| Sietch agent identity | `~/.config/hark/config.json` | `secrets/hark/sietch-config.json.age` |
| Jacurutu agent identity | `~/.config/hark/config.json` | `secrets/hark/jacurutu-config.json.age` |

Each host credential is encrypted only for that host, so one can be revoked
without disabling the other. The same machine connection sends work for every
project. Projects need no token, webhook, local config, or agenix declaration.

## Provision a service integration

A Hark service is appropriate when a non-agent script or external integration
needs independent ownership, revocation, or sender defaults. CI and another
application may qualify. Agent work, including a scheduled agent running as the
user, uses the machine connection and `--project` instead.

1. Run `harkctl services list` and reuse an integration that already owns this
   operational purpose. Creation is not idempotent. If an earlier attempt
   partly succeeded, recover or rotate it through the dashboard rather than
   creating a duplicate.
2. Before creation, run `umask 077` and create a private directory with
   `hark_provision_dir=$(mktemp -d)`. Capture
   `harkctl services create --title <name>` directly into a file there. The JSON
   contains the secret webhook URL, so keep it out of tool output.
3. Parse `.webhookUrl` with a JSON parser. Verify the HTTPS origin is
   `https://hark.sole-pierce.ts.net` and the path begins with `/hooks/`. Write a
   private curl config containing `url = "<webhookUrl>"`.
4. Encrypt that curl config only for the hosts that run the integration. Add
   `secrets/hark/<integration>.curl.age` to `~/dotfiles/secrets.nix`, then add a
   matching `age.secrets` declaration with mode `0600`. Give it a runtime path
   under `~/.config/hark/integrations/`. Do not name it after a project merely
   to sort inbox items.
5. Evaluate every affected NixOS configuration and verify decryption where an
   authorized identity is available, without displaying plaintext. Remove the
   temporary directory after encryption and verification.
6. Leave rebuilds to the user. Report which hosts are prepared and which are
   active. A checkout change does not reach another host until the change is
   transferred and that host is rebuilt.

An integration can still set a project in its request payload. The webhook
selects the sender and authentication; the project controls inbox grouping.

## Renew a machine token

The live config path is an agenix-managed symlink. `harkctl auth login` could
replace it, and `auth logout` could remove it and revoke the host token. Use a
private temporary config for renewal.

Create a directory with `umask 077` and `hark_provision_dir=$(mktemp -d)`, then
set `HARK_CONFIG="$hark_provision_dir/config.json"` for login and validation.
Authorize the login as `Sietch agents` or `Jacurutu agents`. Validate it with
`auth status`, encrypt it only for the target host, and rebuild that host. Revoke
the old token after the replacement works. Record its expiry in the handoff;
agenix does not extend the API token's lifetime.
