# Moving Vaultwarden and Executor to tleilax

This is stage 5 of the fleet security plan. Vaultwarden and Executor leave
sietch and run on tleilax, under the same names and URLs:
`https://vault.sole-pierce.ts.net` and `https://executor.sole-pierce.ts.net`.
sietch keeps its tailnet access to both, but it can't log into tleilax or
decrypt its secrets.

You run every step. Agents don't deploy or touch the machines for this. Each
step says who does it and where:

- **jacurutu**: a bash terminal on the laptop, in `~/dotfiles`.
- **sietch**: a shell on sietch from `ssh sietch`. sudo there asks for your
  password.
- **tleilax**: a shell on tleilax from `ssh tleilax`. sudo there asks for
  nothing.
- **browser**, **Bitwarden client** or **admin console**: as named.

Both services are down from step 5 until step 9 (Vaultwarden) and step 10
(Executor). Plan about an hour for steps 5 to 10. The tleilax deploy in step 4
is slow, so do it earlier the same day.

## Terms

- **advertise**: a host offers a Tailscale Service such as `svc:vault` to the
  tailnet. Tailscale sends `vault.sole-pierce.ts.net` traffic to the host that
  advertises it.
- **serve unit**: on tleilax, `tailscale-serve-vault` and
  `tailscale-serve-executor`. Each advertises its service while the backend
  (`vaultwarden` or `podman-executor`) runs, and withdraws it when the backend
  stops.
- **network namespace**: a separate network stack inside the Linux kernel,
  with its own interfaces, routes and firewall. Executor and the office VPN
  run in one named `executor`.
- **first-start marker**: the file `/var/lib/executor/initialize`. Executor
  starts on an empty database only while it exists, and deletes it on that
  start.
- **final snapshot**: the restic snapshot of sietch's stopped data, tagged
  `stage5-final`.

## What changes, and why

- **Vaultwarden's data moves.** It goes sietch to jacurutu to tleilax over your
  own SSH sessions, because sietch can't reach tleilax. The copy leaves out
  `rsa_key*`, so tleilax makes a new signing key. That signs every client out
  once.
- **Executor starts empty on tleilax.** It doesn't take sietch's `data.db`.
  With a new `EXECUTOR_SECRET_KEY`, every credential stored in the old database
  fails to decrypt. Executor only reports this when a tool runs ("Failed to
  decrypt secret"), and a connection's credential can't be edited, only
  deleted and made again. The bootstrap admin password also only applies to
  an empty database. So a copy would keep the integration list but still need
  every connection and OAuth app redone, and it would bring along whatever
  sietch wrote into that file. Starting empty costs you the integration
  definitions, which step 1 records.
- **All secrets are new.** They are encrypted to tleilax's host key and your
  two YubiKeys, nothing else.
- **sietch stops serving both.** It keeps `/var/lib/vaultwarden` and
  `/var/lib/executor` untouched as the rollback copy.
- **The policy drops `tag:server`** as an approver for `svc:vault` and
  `svc:executor`. sietch keeps its grants to both: agents there use Executor,
  and may get their own Vaultwarden account later.

The config keeps these rules:

1. **Never both at once.** tleilax advertises a service only while its backend
   runs. At boot it withdraws any service whose backend isn't running, since
   tailscaled restores the last serve config after a power cut. The cutover
   withdraws sietch's services (step 6) before tleilax starts its own
   (steps 9 and 10). The rollback stops tleilax first.
2. **Never on empty data.** Vaultwarden starts only when
   `/var/lib/vaultwarden/db.sqlite3` exists. Executor starts only when
   `/var/lib/executor/data.db` or the first-start marker exists. Both refuse
   to start while their secrets hold the `REPLACE_ME` placeholders. Executor
   also needs the bootstrap admin set, so nobody else can claim an empty
   instance.
3. **The copy goes through jacurutu** and keeps file modes. tleilax re-owns the
   files to its own `vaultwarden` user, whose UID may differ from sietch's
   (992).
4. **There is a rollback** at the end of this file.

`tests/tleilax-credentials.nix` is a VM test of rules 1 and 2 and of the
namespace. The commands are in its header.

## Before you start

- The PR that added this file is merged into `nixos`.
- yk-nfc is plugged into jacurutu. yk-nano helps for one optional check.
- A Bitwarden client you use every day, signed in and synced: the phone app,
  or the browser extension on jacurutu. Step 9 tests the vault with it.
  WebAuthn is bound to `vault.sole-pierce.ts.net`, so nothing on localhost can
  stand in for it.
- About an hour for steps 5 to 10.

## 1. Record Executor's setup (browser, while sietch still serves)

tleilax's Executor starts empty, so write down what you'll rebuild. Open
`https://executor.sole-pierce.ts.net` and note, for each integration:

- its name and slug. `agents/skills/executor` searches `google`, `slack_mcp`,
  `raindrop_io` and `railway_mcp`, so reuse the same names;
- its kind (MCP server, OpenAPI, GraphQL) and its URL or spec;
- how it authenticates: OAuth through your own OAuth app (note the client
  ID), OAuth with dynamic registration, or a static API key;
- its connections, and which account each one is;
- its tool policies (allow, approve, block);
- where to revoke its grant at the provider. For example, Google lists apps
  at `https://myaccount.google.com/connections`, and Spotify at
  `https://www.spotify.com/account/apps/`.

Also note the API keys under Settings and which client uses each.
meeting-minutes and russ-playlist-sync use keys. Codex, Claude Code, opencode
and T3 sign in with MCP OAuth.

Screenshots are fine. Don't copy any secret values.

## 2. Make the new passwords (Bitwarden client, while sietch still serves)

Make two items now. They sync to sietch and come along with the copy, so
they're in the vault on tleilax too.

- **Vaultwarden admin token (tleilax)**: a generated passphrase. You type it
  on the admin page. The server keeps only its hash.
- **Executor admin (tleilax)**: your Executor login email as the username,
  and a generated passphrase with hyphens as the password. Step 3 accepts only
  letters, digits and `- . _ ~` in it, so the env file can't mangle it.

Keep the admin token on the paper recovery sheet too. The vault is locked
inside the box it administers.

## 3. Fill the secrets (jacurutu)

First check what sietch's Vaultwarden env file sets besides `ADMIN_TOKEN`. On
**sietch**, from `~/dotfiles`, this prints variable names only:

```sh
agenix -d secrets/selfhost/vaultwarden-env.age | cut -d= -f1
```

It should print `ADMIN_TOKEN` alone. If it lists more (SMTP or push relay
settings), add those lines to `vaultwarden.env` below, with new values for
anything secret.

Then on **jacurutu**:

```sh
cd ~/dotfiles
git switch nixos && git pull --ff-only
umask 077
d=$(mktemp -d)

# Paste the admin token from the vault item at both prompts.
nix shell nixpkgs#vaultwarden -c vaultwarden hash > "$d/hash.out"
grep '^ADMIN_TOKEN=' "$d/hash.out" > "$d/vaultwarden.env" && echo "hash ok"

read -rp 'Executor admin email: ' email
read -rsp 'Executor admin password: ' pw; echo
if [[ $email =~ ^[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+$ && $pw =~ ^[A-Za-z0-9._~-]{16,}$ ]]; then
  {
    printf 'EXECUTOR_SECRET_KEY=%s\n' "$(openssl rand -hex 32)"
    printf 'BETTER_AUTH_SECRET=%s\n' "$(openssl rand -hex 32)"
    printf 'EXECUTOR_BOOTSTRAP_ADMIN_EMAIL=%s\n' "$email"
    printf 'EXECUTOR_BOOTSTRAP_ADMIN_PASSWORD=%s\n' "$pw"
  } > "$d/executor.env" && echo "env ok"
else
  echo "unexpected character, or a password under 16 characters; run these lines again"
fi
unset email pw

EDITOR="cp $d/vaultwarden.env" agenix -e secrets/tleilax/vaultwarden-env.age -i ~/.config/age/yk-nfc.txt
EDITOR="cp $d/executor.env" agenix -e secrets/tleilax/executor-env.age -i ~/.config/age/yk-nfc.txt
rm -rf "$d"
```

Success is `hash ok` and `env ok`. If the two `vaultwarden hash` entries
didn't match, `hash ok` doesn't appear; run those two lines again. Each
`agenix -e` asks for the PIV PIN and a touch, to read the placeholder.
Writing needs neither.

Check them without printing the values:

```sh
for f in vaultwarden-env executor-env; do
  agenix -d secrets/tleilax/$f.age -i ~/.config/age/yk-nfc.txt |
    awk -F= '{ print $1, ($2 == "REPLACE_ME" ? "PLACEHOLDER" : "set") }'
done
```

Success is `ADMIN_TOKEN set`, then the four Executor names, each `set`. If
yk-nano is at hand, run it once more with `yk-nano.txt`.

```sh
git add secrets/tleilax
git commit -m "tleilax: Vaultwarden and Executor secrets"
git push origin nixos
```

## 4. Deploy tleilax and check it (jacurutu, then tleilax)

This deploy changes nothing anyone uses. Neither service can start yet,
because neither has data.

```sh
deploy tleilax
```

It signs and pushes a tag (PIN and touch, twice), then tleilax builds its own
aarch64 closure. Expect it to take a while.

Then on **tleilax**:

```sh
systemctl show -p Id -p ActiveState -p ConditionResult vaultwarden podman-executor
systemctl is-active executor-netns executor-proxy.socket tailscale-serve-config
sudo tailscale serve status --json
systemctl --failed
```

Success:

- both services show `ActiveState=inactive` and `ConditionResult=no`;
- the three units print `active`;
- the serve status lists no services;
- no failed units.

Pull the Executor image and check that it runs on the Pi's CPU and reaches
the internet from the namespace:

```sh
image=ghcr.io/usefulsoftwareco/executor-selfhost:v1.6.11@sha256:ea8b4d1019cc00c81cb4236d8edc07a12ac75ef465593b89ae652c0800cd33c1
sudo podman pull "$image"
sudo podman run --rm --network=none "$image" bun --version
sudo podman run --rm --network=ns:/run/netns/executor --dns=10.0.0.1 "$image" \
  bun -e 'fetch("https://cache.nixos.org/nix-cache-info").then((r) => console.log(r.status))'
sudo ip netns exec executor curl -sS --max-time 5 http://10.0.0.1/; echo "exit=$?"
```

Success: a bun version, then `200`, then a curl timeout with a non-zero exit.
That timeout is the namespace refusing the LAN. `Illegal instruction` would
mean the image doesn't run on the Pi 4. Then don't start step 5: step 6 would
take Executor off sietch with nowhere to go. The config needs to keep
Executor on sietch first.

**The cutover starts here.**

## 5. Stop both on sietch and take the final snapshot (sietch)

First pause the nightly backup and let any run in progress finish. If you
started the backup while a run was still going, systemd would hand you that
run, which copied the databases before you stopped the services.

```sh
sudo systemctl stop restic-backups-services.timer
until systemctl show -P ActiveState restic-backups-services | grep -qxE 'inactive|failed'; do sleep 5; done
```

Success: the loop returns, at once if no backup was running.

Then stop both services and start a new backup run:

```sh
sudo systemctl stop vaultwarden docker-executor
systemctl is-active vaultwarden docker-executor
date
sudo systemctl start restic-backups-services
systemctl show -p Result restic-backups-services
sudo restic-services snapshots --tag services --latest 1
sudo systemctl start restic-backups-services.timer
```

Success: `inactive` twice, the backup returns within a few minutes, then
`Result=success` and one snapshot whose time is later than what `date`
printed. If the backup fails, start everything again
(`sudo systemctl start vaultwarden docker-executor restic-backups-services.timer`)
and stop here.

Tag it, so pruning keeps it if pruning is ever switched on:

```sh
sudo restic-services tag --add archive --add stage5-final <ID>
sudo restic-services snapshots --tag stage5-final
```

Tagging rewrites the snapshot, so the second command shows its new ID. Write
that ID in the fleet security plan task note. Check that it holds both
databases:

```sh
sudo restic-services ls <new ID> /var/lib/backup-staging/services/vaultwarden /var/lib/backup-staging/services/executor
```

Success: `db.sqlite3` and `data.db` in the listing.

Don't reboot sietch before step 6. Its config still starts both services at
boot.

## 6. Deploy sietch (jacurutu)

```sh
deploy sietch
```

sietch drops both services and withdraws `svc:vault` and `svc:executor`.
Check from jacurutu:

```sh
ssh -T sietch 'systemctl is-active vaultwarden docker-executor; tailscale serve status --json | jq -r ".Services // {} | keys[]"; ls -ld /var/lib/vaultwarden /var/lib/executor'
```

Success: `inactive` twice, a service list without `svc:vault` and
`svc:executor`, and both directories still there.

If the deploy fails, check whether sietch switched to the new config before
it failed:

```sh
ssh -T sietch 'systemctl cat vaultwarden.service docker-executor.service >/dev/null 2>&1 && echo "old config" || echo "new config"'
```

- `old config`: the deploy failed before switching. Run
  `sudo systemctl start vaultwarden docker-executor` on sietch and stop here.
- `new config`: sietch switched, then something else failed. The old units
  and their secrets are gone, so they can't be started by hand. The data is
  untouched. If the failure is unrelated (`systemctl --failed` on sietch),
  fix it and carry on with step 7. To put both services back on sietch
  instead, follow [Rollback](#rollback) steps 3 to 5. Skip steps 1 and 2:
  tleilax has no data yet and the policy isn't pasted.

## 7. Copy Vaultwarden's data (jacurutu)

Read it from sietch. sudo there needs your password, which this passes to
`sudo -S` on standard input, so the tar stream stays clean:

```sh
umask 077
mkdir -p ~/stage5
read -rsp 'sudo password on sietch: ' pw; echo
printf '%s\n' "$pw" | ssh -T sietch \
  "sudo -S -p '' tar -C /var/lib --numeric-owner --exclude='vaultwarden/rsa_key*' --exclude=vaultwarden/icon_cache -cf - vaultwarden" \
  > ~/stage5/vaultwarden.tar
echo "exit=$?"
unset pw
tar -tvf ~/stage5/vaultwarden.tar > ~/stage5/list.txt
if grep -q rsa_key ~/stage5/list.txt; then echo "rsa_key is in the copy; stop"; else echo "no rsa_key"; fi
less ~/stage5/list.txt
```

Success: `exit=0`, `no rsa_key`, and a listing with `vaultwarden/db.sqlite3`,
owned by `992/989`, with modes `-rw-------` and `drwx------`. `icon_cache` is
a cache and comes back on its own.

Check the copy on jacurutu before sending it:

```sh
tar -xOf ~/stage5/vaultwarden.tar vaultwarden/db.sqlite3 | sha256sum
mkdir -p ~/stage5/check
tar -C ~/stage5/check -xf ~/stage5/vaultwarden.tar
nix shell nixpkgs#sqlite -c sqlite3 ~/stage5/check/vaultwarden/db.sqlite3 'PRAGMA integrity_check'
rm -rf ~/stage5/check
```

Success: a checksum, then `ok`. Keep the checksum on screen. It comes from
the archive itself, because the integrity check can rewrite its own copy.

Write it to tleilax. It goes into a staging directory first.
`/var/lib/vaultwarden` appears only once the data is complete and cleaned
up, in one rename. tleilax starts Vaultwarden at boot as soon as that
directory holds a database, so a half-written copy there could start after a
power cut. Nothing should be there yet:

```sh
ssh -T tleilax 'sudo test -e /var/lib/vaultwarden && echo "already there; stop and look" || echo "empty"'
ssh -T tleilax 'set -e; sudo rm -rf /var/lib/vaultwarden.import; sudo install -d -m 0700 /var/lib/vaultwarden.import; sudo tar -C /var/lib/vaultwarden.import --numeric-owner -xpf -; echo "tar exit=0"' \
  < ~/stage5/vaultwarden.tar
ssh -T tleilax 'sudo sha256sum /var/lib/vaultwarden.import/vaultwarden/db.sqlite3'
```

Success: `empty`, `tar exit=0`, and the same checksum as on jacurutu. If
either is missing, run the second command again.

Vaultwarden lets settings saved from the admin page override the
environment, including the admin token. List the saved keys, without values:

```sh
ssh -T tleilax 'sudo test -e /var/lib/vaultwarden.import/vaultwarden/config.json && sudo jq -r "keys[]" /var/lib/vaultwarden.import/vaultwarden/config.json'
```

If it lists `admin_token` or `disable_admin_token`, remove them, or the old
token keeps working and the new one doesn't:

```sh
ssh -T tleilax "sudo sh -c 'cd /var/lib/vaultwarden.import/vaultwarden && jq \"del(.admin_token, .disable_admin_token)\" config.json > config.json.new && chmod 0600 config.json.new && mv config.json.new config.json'"
```

Then hand it to tleilax's `vaultwarden` user and move it into place:

```sh
ssh -T tleilax 'set -e; sudo chown -R vaultwarden:vaultwarden /var/lib/vaultwarden.import/vaultwarden; sudo mv -T /var/lib/vaultwarden.import/vaultwarden /var/lib/vaultwarden; sudo rmdir /var/lib/vaultwarden.import; sync'
ssh -T tleilax 'sudo find /var/lib/vaultwarden -maxdepth 1 -printf "%M %u %g %p\n"'
```

Success: a listing owned by `vaultwarden vaultwarden` with the same modes,
including `db.sqlite3` and no `rsa_key`.

## 8. Paste the policy (admin console)

sietch no longer advertises either service, so take away its approval. Paste
`docs/tailscale-policy.jsonc` into the policy editor and save. The editor
runs the file's tests and refuses a policy that fails them. They include
sietch still reaching `svc:vault` and `svc:executor`.

## 9. Start Vaultwarden and test it with a real client (tleilax, then a client)

```sh
sudo systemctl start vaultwarden
systemctl is-active vaultwarden tailscale-serve-vault
sudo tailscale serve status --json | jq -r '.Services // {} | keys[]'
curl -fsS http://127.0.0.1:8222/alive; echo
sudo ls -l /var/lib/vaultwarden/rsa_key.pem
journalctl -u vaultwarden -b -n 30 --no-pager
```

Success: `active` twice, `svc:vault`, a timestamp from `/alive`, an
`rsa_key.pem` made just now, and no errors in the log. On the admin console's
Services page, `svc:vault` should list tleilax as its host.

Then in your **Bitwarden client**:

1. It shows you as logged out, because the signing key is new. Log in with
   the same server URL, your master password and your YubiKey.
2. Unlock. Open a few items and an attachment, if you have one.
3. Add a test item, sync a second client, see it there, then delete it.
4. Open `https://vault.sole-pierce.ts.net/admin` and log in with the new
   admin token. Under Users, check that only the accounts you expect are
   there.

If all four work, delete the local copy: `rm -rf ~/stage5` on jacurutu.

If a client can't log in or unlock, go to "Rollback" now, before step 10.

## 10. Start Executor and rebuild it (tleilax, then browser)

```sh
sudo touch /var/lib/executor/initialize
sudo systemctl start podman-executor
systemctl is-active podman-executor tailscale-serve-executor
sudo test ! -e /var/lib/executor/initialize && echo "marker used"
sudo test -e /var/lib/executor/data.db && echo "database created"
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8302/
```

Success: `active` twice, both messages, and an HTTP status such as `200` or
`302`. Bun takes a few seconds to start, so `activating`, `000` or `502` right
away means try again.

In the **browser**, open `https://executor.sole-pierce.ts.net` and log in with
the bootstrap email and password from the vault item. Check that you're the
only member.

Then, for each integration from step 1:

1. **Revoke the old grant at the provider first.** The old tokens are still
   valid, and they sit encrypted in sietch's copy and in the final snapshot.
2. If it uses your own OAuth app, make a new client secret at the provider
   and delete the old one.
3. If it uses a static API key, make a new key and revoke the old one.
4. Add the integration in Executor with the same name, connect it, and grant
   access.
5. Set its tool policies again.
6. Run one read-only tool to check it, for example a Gmail search.

## 11. New keys for Executor's clients (Executor, then jacurutu)

MCP clients (Codex, Claude Code, opencode, T3) ask you to sign in again the
next time they use Executor. For Codex, `codex mcp login executor`. In Claude
Code, `/mcp`.

meeting-minutes and russ-playlist-sync use API keys. Make one key for each in
Executor's settings, then on **jacurutu**:

```sh
cd ~/dotfiles
umask 077
d=$(mktemp -d)
read -rsp 'meeting-minutes key: ' key; echo
printf 'EXECUTOR_API_KEY=%s\n' "$key" > "$d/meeting-minutes"
read -rsp 'russ-playlist-sync key: ' key; echo
printf 'EXECUTOR_API_KEY=%s\n' "$key" > "$d/russ-playlist-sync"
unset key
EDITOR="cp $d/meeting-minutes" agenix -e secrets/executor/meeting-minutes.age
EDITOR="cp $d/russ-playlist-sync" agenix -e secrets/executor/russ-playlist-sync.age
rm -rf "$d"
git add secrets/executor
git commit -m "executor: client keys for tleilax's Executor"
git push origin nixos
deploy sietch
rebuild
```

These two files are encrypted to the sietch and jacurutu user keys, as
before, because those clients run there.

## 12. The office VPN (jacurutu, then tleilax, whenever you're ready)

The cutover doesn't need this. Executor serves without it, and the tunnel
stays off until its secret file exists.

Download `tony2.zip` from Slack on jacurutu, then look at what's inside. This
prints file names and the non-key settings only:

```sh
umask 077
d=$(mktemp -d)
unzip -l ~/Downloads/tony2.zip
unzip -q ~/Downloads/tony2.zip -d "$d/zip"
find "$d/zip" -type f
```

Build one file with the key material as inline blocks. If the zip has
separate files (adjust the names to what `find` printed):

```sh
z=$d/zip
{
  echo '<ca>'; cat "$z/ca.crt"; echo '</ca>'
  echo '<cert>'; cat "$z/tony2.crt"; echo '</cert>'
  echo '<key>'; cat "$z/tony2.key"; echo '</key>'
  echo '<tls-auth>'; cat "$z/ta.key"; echo '</tls-auth>'
} > "$d/executor-vpn.conf"
```

If it has one `.ovpn` file, keep only its blocks, and print its other
settings to compare:

```sh
blocks='^</?(ca|cert|key|tls-auth|tls-crypt)>'
awk -v b="$blocks" '$0 ~ b && !/^<\//{keep=1} keep{print} $0 ~ b && /^<\//{keep=0}' "$d"/zip/*.ovpn > "$d/executor-vpn.conf"
awk -v b="$blocks" '$0 ~ b && !/^<\//{skip=1} !skip{print} $0 ~ b && /^<\//{skip=0}' "$d"/zip/*.ovpn
```

tleilax uses `remote 71.25.106.254 1194` over UDP, `auth SHA1`,
`key-direction 1` and `remote-cert-tls server`, as `moberg-vpn.nix` does. If
the `.ovpn` says something different, change the `vpn` settings in
`machines/tleilax/executor.nix` to match before going on. A `<tls-crypt>`
block instead of `<tls-auth>` works as it is.

Check the file without printing it:

```sh
grep -c '^<' "$d/executor-vpn.conf"
grep -c ENCRYPTED "$d/executor-vpn.conf"
```

Success: `8` (four blocks, opening and closing tags), then `0`. A key with a
passphrase would show `ENCRYPTED`, and this config can't type one.

Encrypt it, clean up and deploy:

```sh
cd ~/dotfiles
EDITOR="cp $d/executor-vpn.conf" agenix -e secrets/tleilax/executor-vpn.age
rm -rf "$d" ~/Downloads/tony2.zip
git add secrets/tleilax/executor-vpn.age
git commit -m "tleilax: office VPN credential for Executor"
git push origin nixos
deploy tleilax
```

Then on **tleilax**, with an office host and port you know answers HTTP:

```sh
systemctl is-active openvpn-executor-vpn
sudo ip -n executor -4 route
sudo ip netns exec executor curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 http://<office host>:<port>/
curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 http://<office host>:<port>/; echo "exit=$?"
```

Success:

- `active`;
- four routes, in this shape (the tunnel addresses come from the office
  server, so they may differ):

  ```text
  default via 10.231.0.1 dev vex-ns
  10.1.10.0/24 via 10.8.0.1 dev tun0
  10.8.0.0/24 dev tun0 proto kernel scope link src 10.8.0.2
  10.231.0.0/30 dev vex-ns proto kernel scope link src 10.231.0.2
  ```

  No `0.0.0.0/1` or `128.0.0.0/1`, which would mean the office's default
  route got in, and nothing else via `tun0`;
- an HTTP status from inside the namespace;
- a failure from the host itself, which has no route to the office.

Executor itself still refuses 10.1.10.x while `EXECUTOR_ALLOW_LOCAL_NETWORK`
is `false`. Its guard blocks all of 10.0.0.0/8, by address and by what a name
resolves to. Office MCP servers need it set to `true` in
`machines/tleilax/executor.nix`. In the namespace "local" can only mean
Executor's own loopback and the office subnet.

## Rollback

### The same day, before step 10's revocations

Use this if a client can't log in or unlock in step 9. The order matters:
tleilax stops advertising before sietch starts again.

1. **tleilax**: stop both and move their data aside, so neither starts or is
   advertised again, even after a reboot:

   ```sh
   sudo systemctl stop vaultwarden podman-executor
   sudo mv /var/lib/vaultwarden /var/lib/vaultwarden.failed
   sudo mv /var/lib/executor /var/lib/executor.failed
   sync
   sudo tailscale serve status --json | jq -r '.Services // {} | keys[]'
   ```

   Success: the last command prints nothing. `sync` matters: in the VM test,
   a power cut a moment after the `mv` lost the rename, and Vaultwarden came
   back at boot.

2. **Admin console**: paste the policy from before the PR, which makes
   `tag:server` an approver again. Find the PR's merge commit on GitHub, then
   on jacurutu:

   ```sh
   git -C ~/dotfiles show <merge commit>^1:docs/tailscale-policy.jsonc
   ```

3. **jacurutu**: restore sietch's config from before the PR, and deploy it:

   ```sh
   cd ~/dotfiles
   git switch nixos && git pull --ff-only
   git checkout <merge commit>^1 -- modules/nixos/selfhost machines/sietch/default.nix \
     machines/tleilax/services.nix docs/tailscale-policy.jsonc
   git status --short
   git commit -m "Roll back stage 5: Vaultwarden and Executor return to sietch"
   git push origin nixos
   deploy sietch
   ```

   `git status` should list only those paths. If a later commit changed
   `machines/sietch/default.nix`, compare with `git diff --cached` and keep
   that change.

4. **Check sietch** from jacurutu:

   ```sh
   ssh -T sietch 'systemctl is-active vaultwarden docker-executor; tailscale serve status --json | jq -r ".Services // {} | keys[]"'
   ```

   Success: `active` twice, and both services listed. A Bitwarden client
   logs in again (sietch has its old signing key) and unlocks.

5. `deploy tleilax`, to drop the services from its config.

Anything saved to the vault after step 9 is only in
`/var/lib/vaultwarden.failed` on tleilax. Add it again on sietch. Delete the
`.failed` directories once you've decided what went wrong.

### Later

Once tleilax's vault has changes sietch's copy lacks, a rollback has to copy
tleilax's data back. Stop Vaultwarden on both, copy
`tleilax:/var/lib/vaultwarden` to sietch through jacurutu as in step 7 (the
other way round, re-owned to sietch's `vaultwarden`), then run steps 1 to 5
above. After step 10, sietch's Executor holds grants you revoked, so it needs
its connections redone there too.

## What stays on sietch, and until when

- `/var/lib/vaultwarden`, with the old signing key, and `/var/lib/executor`,
  root-only and untouched;
- the final snapshot, tagged `archive` and `stage5-final`;
- the old secrets `secrets/selfhost/vaultwarden-env.age` and
  `secrets/selfhost/executor-env.age`, with their `secrets.nix` entries. A
  rollback needs them, and so does reading the old Executor snapshot;
- the Executor image in sietch's Docker data root.

A later PR adds tleilax's own backup job. Once that job has passed a restore
check, a cleanup PR deletes the two directories on sietch, the two old
secrets and their entries, and the image, and updates `docs/backups.md`. The
final snapshot stays in sietch's repository.

## Unverified

- Nobody has built tleilax's new closure yet. sietch has no aarch64 builder,
  so the PR only evaluates it. Step 4's deploy is the first build.
- That the arm64 Executor image runs on the Pi 4's CPU. Step 4 checks it
  before anything stops.
- The VM test runs these modules with tleilax's own `network.nix` on x86_64:
  the first-deploy switch, the namespace, the serve units, the start guards,
  a power cut, and OpenVPN against a test server that pushes extra routes, a
  default gateway and DNS. It uses a stand-in for the tailscale CLI and a
  stub in place of the Executor image. Untested: the real tailscale CLI
  withdrawing a service on `serve clear`, the Moberg server accepting this
  client config, and the contents of `tony2.zip`.
