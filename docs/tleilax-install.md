# tleilax fresh install

This wipes the Raspberry Pi 4 and reinstalls it from the root flake as a
locked-down box for credential services. It ends with tleilax:

- booting from the 1 TB Samsung T5 USB SSD, with its root on LUKS2 (Adiantum);
- waiting at boot for its disk passphrase, which you type over SSH from
  jacurutu (directly at home, through sietch when away) or on the HDMI console;
- on the tailnet as `tag:credentials`, reachable only from jacurutu;
- taking signed deploys from jacurutu like sietch does.

The config is `machines/tleilax/`. Steps say where they run: **jacurutu**, the
**Pi console** (HDMI and a USB keyboard), the **installer** (the NixOS image
running on the Pi), or the **Tailscale admin console**.

Lines marked **Unverified** describe things nobody has tested on this Pi yet.
They are collected again at the end.

## Before you start

You need:

- the PR that added this file merged into `nixos`;
- yk-nfc and yk-nano;
- an SD card for the installer. Use a spare one if the inventory shows data on
  the Pi's current 128 GB card;
- a micro-HDMI monitor and a USB keyboard on the Pi, and Ethernet;
- access to the router's admin page, for a DHCP reservation.

Pick the disk passphrase now and store it somewhere that doesn't depend on
the Pi. Vaultwarden will move to tleilax, so a copy only in Vaultwarden is
locked inside the box it unlocks.

## 1. Inventory the old Pi (jacurutu, read-only)

Nothing here changes the Pi. It records what might hold data worth keeping.
Run it before anything else, and copy off whatever you want before step 5.

```sh
ssh -T tleilax 'sudo bash -s' > ~/tleilax-inventory.txt 2>&1 <<'EOF'
set -x
nixos-version; uptime
cat /proc/device-tree/model; echo
# Disks, partitions, and what is mounted where. Is root on the SD card
# (mmcblk0) or on the SSD (sda)?
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINTS,MODEL,SERIAL,TRAN
findmnt -no SOURCE,TARGET,FSTYPE / /boot /boot/firmware
blkid
df -h
# The last rebuild started ZFS units. List pools without importing any.
if command -v zpool; then zpool list; zpool import; zfs list; fi
systemctl list-units --all --no-pager 'zfs*'
# Service state. tleilax-remote kept tokens and job logs; the T3 preview's
# proxies kept OpenAI and Claude logins under t3-openai-proxy and
# t3-claude-proxy.
du -xsh /var/lib/* 2>/dev/null | sort -h
ls -la /var/lib
# The T3 preview's home: projects, plus Codex, Claude and Pi agent state.
du -xsh /home/kabilan/.t3-v2-preview-1887/* 2>/dev/null
# Everything else in the home directory, largest last.
du -xsh /home/kabilan/* /home/kabilan/.[!.]* 2>/dev/null | sort -h | tail -40
EOF
less ~/tleilax-inventory.txt
```

`ssh tleilax` asks for one touch and reuses the connection for the rest.

Read it for:

- **A ZFS pool.** `zpool import` with no arguments only lists pools it could
  import. The ZFS units likely come from the old SD-image profile, which turns
  on ZFS support whether or not a pool exists. If the inventory shows a pool,
  save its data before step 5.
- **The SSD's contents.** If `lsblk` shows partitions on `sda` that aren't
  mounted, look inside read-only. For ext4, `noload` skips the journal replay
  so nothing is written:

  ```sh
  ssh tleilax 'sudo mount -o ro,noload /dev/sda1 /mnt && ls -la /mnt && sudo umount /mnt'
  ```

  Use plain `-o ro` for FAT. Repeat for each partition.
- **`/var/lib`** and **`~/.t3-v2-preview-1887/projects`**, for anything you
  made on the Pi.
- **The OpenAI and Claude logins** under `/var/lib/t3-openai-proxy` and
  `/var/lib/t3-claude-proxy`. The wipe deletes the files, but those sessions
  stay valid at the providers until you sign them out there.

Copy anything you keep to jacurutu, for example
`rsync -a tleilax:/path/ ~/tleilax-backup/path/`.

Also note where the Pi boots from. If root is on the SD card, keep that card
as it is and use a different one for the installer. Then putting it back is
the rollback (step 12).

**Unverified:** that this Pi's EEPROM boots from USB and reads GPT partition
tables. The new layout needs both. If the Pi boots from the SSD today, USB
boot already works.

## 2. Rebuild jacurutu

On jacurutu, pull the merged `nixos` and run `rebuild`. This adds `pcscd` and
`age-plugin-yubikey` for step 3, and makes `deploy` accept tleilax.

## 3. YubiKey age identities (jacurutu)

tleilax's secrets are encrypted to its own SSH host key and to one age
identity on each YubiKey, and to nothing else. Do this once per key: yk-nfc,
then yk-nano.

Each YubiKey has two PINs. The FIDO PIN is for SSH and passkeys. The PIV PIN
is for age. They are separate, so this step doesn't touch your SSH keys or
passkeys. You may give both PINs the same value.

```sh
nix shell nixpkgs#yubikey-manager
ykman piv info
```

If it warns that the PIN, PUK or management key is still the factory default,
change them. The defaults are PIN `123456` and PUK `12345678`.

```sh
ykman piv access change-pin
ykman piv access change-puk
ykman piv access change-management-key --generate --protect
```

Then make the identity. It asks for the PIV PIN and a touch.

```sh
mkdir -p ~/.config/age
age-plugin-yubikey --generate --name yk-nfc --pin-policy once --touch-policy always \
  > ~/.config/age/yk-nfc.txt
age-plugin-yubikey --list
```

The file is a stub that points at the YubiKey, like the SSH handle files. It
does nothing without the key. Copy the `age1yubikey1...` recipient that
`--list` prints. Repeat with yk-nano, `--name yk-nano` and
`~/.config/age/yk-nano.txt`.

To edit a tleilax secret later, pass the stub of the key you have plugged in:
`agenix -e <file> -i ~/.config/age/yk-nfc.txt`.

Put both recipients in `lib/fleet.nix`:

```nix
  ageRecipients = [
    "age1yubikey1..." # yk-nfc
    "age1yubikey1..." # yk-nano
  ];
```

`secrets.nix` only offers tleilax's secret rules once both are listed, so
nothing gets encrypted without them. Commit this together with the keys in
step 7.

## 4. Tailnet policy and the first-boot key (Tailscale admin console)

1. Paste `docs/tailscale-policy.jsonc` into the policy editor and save. It
   adds `tag:credentials`, the only tag allowed to advertise `svc:vault` and
   `svc:executor`. It drops sietch's grant to tleilax and lets
   `tag:credentials` reach `svc:hark` for alerts.
2. Check Vaultwarden right away. It still runs on sietch until stage 5, and
   sietch's `tag:server` no longer auto-approves `svc:vault` or
   `svc:executor`. On the Services page, sietch should still be an approved
   host of both. Open the vault in a browser or sync a Bitwarden client.
   **Unverified:** Tailscale's docs say auto-approval happens only when a
   service is first advertised, but not whether removing an approver revokes
   an existing approval. If sietch shows as pending, approve it by hand on
   the Services page. The policy file stays as it is.
3. Settings, Keys: generate an auth key. Not reusable, not ephemeral,
   pre-approved, tag `tag:credentials`, expiring in a day. Keep it on screen
   for step 6. It is used once, at tleilax's first boot.

## 5. Start the installer on the Pi

On jacurutu, download the NixOS aarch64 SD image from Hydra. Use the latest
successful build of `nixos.sd_image.aarch64-linux`, for example at
<https://hydra.nixos.org/job/nixos/trunk-combined/nixos.sd_image.aarch64-linux>.
Check the file's SHA-256 against the one Hydra lists. **Unverified:** the exact
jobset name; nix.dev's Raspberry Pi guide links the current one.

Flash it. Check with `lsblk` that `/dev/sdX` is the SD card reader and not
another disk:

```sh
zstd -d nixos-sd-image-*-aarch64-linux.img.zst -o /tmp/installer.img
lsblk
sudo dd if=/tmp/installer.img of=/dev/sdX bs=4M conv=fsync status=progress
```

At the Pi:

1. Power off. Insert the installer SD card and connect Ethernet, HDMI and the
   keyboard.
2. Power on. The installer logs in as `nixos` on the console.
3. If the Pi boots the old system from the SSD instead, its boot order tries
   USB first. Unplug the SSD, power-cycle, and plug the SSD back in once the
   installer is up.

On the Pi console, set a temporary password so you can work from jacurutu,
and note the address and the host key fingerprint:

```sh
passwd
ip -4 addr show
ip link
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Reserve the Pi's address on the router for the Ethernet MAC address that
`ip link` shows (the `en...` or `eth0` entry). The installed system uses the
same interface, so it gets the same address. The rest of this file calls it
`LAN_IP`.

From jacurutu, connect and compare the fingerprint ssh shows with the one on
the console before you answer yes:

```sh
ssh -o UserKnownHostsFile=/dev/null nixos@LAN_IP
```

Everything in steps 6 and 7 runs in that session as root:

```sh
sudo -i
export NIX_CONFIG="experimental-features = nix-command flakes"
```

## 6. Partition, encrypt and prepare the SSD (installer)

Pin the exact commit you reviewed. On jacurutu, `git -C ~/dotfiles fetch` and
`git -C ~/dotfiles rev-parse origin/nixos` give it. Then, in the installer:

```sh
FLAKE=github:Kabilan108/dotfiles/<full commit hash>
nix flake metadata "$FLAKE"   # Revision: must match the hash
```

Installing from an exact commit sets the system's configuration revision. The
deploy receiver needs it to accept later deploys.

Make sure the SSD is `/dev/sda` and is the only USB disk. The disk layout in
`machines/tleilax/disko.nix` formats `/dev/sda`.

```sh
lsblk -o NAME,SIZE,MODEL,SERIAL,TRAN
```

It should show `sda`, about 931G, model `Portable SSD T5`, transport `usb`.
Unplug any other USB storage.

Build the disk script and run it. It lists the disk and asks you to type
`yes`, then asks for the disk passphrase twice. Formatting the LUKS volume
times the key derivation on the Pi, so later unlocks take a couple of seconds.

```sh
disko=$(nix build --no-link --print-out-paths \
  "$FLAKE#nixosConfigurations.tleilax.config.system.build.destroyFormatMount")
"$disko/bin/disko-destroy-format-mount"
```

Check the result. Root should be mounted at `/mnt` and the boot partition at
`/mnt/boot`, with Adiantum as the cipher:

```sh
lsblk -f /dev/sda
findmnt -R /mnt
cryptsetup luksDump /dev/disk/by-partlabel/disk-ssd-root | grep -i cipher
```

Optional: keep a LUKS header backup off the Pi. With the passphrase it can
open the disk, so store it like a secret.

```sh
cryptsetup luksHeaderBackup /dev/disk/by-partlabel/disk-ssd-root \
  --header-backup-file /tmp/tleilax-luks-header.img
```

Copy it to jacurutu with `scp` from there, then `rm` it here.

**Host keys.** The system key stays on the encrypted root. agenix decrypts
tleilax's secrets with it. The boot environment gets its own key, kept on the
unencrypted boot partition, because the initrd has to read it before the disk
is open.

```sh
mkdir -p /mnt/etc/ssh
ssh-keygen -t ed25519 -N "" -C root@tleilax -f /mnt/etc/ssh/ssh_host_ed25519_key

mkdir -p /tmp/initrd-key /mnt/boot/initrd-ssh
ssh-keygen -t ed25519 -N "" -C tleilax-initrd -f /tmp/initrd-key/ssh_host_ed25519_key
cp /tmp/initrd-key/ssh_host_ed25519_key /mnt/boot/initrd-ssh/

cat /mnt/etc/ssh/ssh_host_ed25519_key.pub
cat /tmp/initrd-key/ssh_host_ed25519_key.pub
```

Keep both public keys for step 7. They are public. FAT has no permissions, so
the key is generated in `/tmp` and copied. The boot partition is mounted
root-only.

**Pi firmware and u-boot.** nixos-install writes the kernels and
`extlinux.conf`. The Pi firmware, u-boot and `config.txt` are copied once:

```sh
firmware=$(nix build --no-link --print-out-paths \
  "$FLAKE#nixosConfigurations.tleilax.config.system.build.raspberryPiFirmware")
cp -r "$firmware"/. /mnt/boot/
```

**The first-boot Tailscale key.** Paste the auth key from step 4 at the
prompt. It isn't echoed or kept in shell history.

```sh
install -d -m 0700 /mnt/var/lib/tailscale
read -rs key && (umask 077; printf '%s' "$key" > /mnt/var/lib/tailscale/first-boot-auth-key); unset key
```

## 7. Install, and record the keys (installer and jacurutu)

The first build is aarch64, so it runs on the Pi, in the installer. jacurutu
has no aarch64 emulation, and sietch must never build for tleilax. A dry run
at the PR's commit counted about 480 MiB to download from cache.nixos.org and
about 300 small local builds (config files, the initrd, home files), with
nothing to compile. The kernel and u-boot come from the cache.

If the Pi has little RAM, add swap on the encrypted root first, and remove it
after the install:

```sh
fallocate -l 4G /mnt/swapfile && chmod 600 /mnt/swapfile && mkswap /mnt/swapfile && swapon /mnt/swapfile
```

Install:

```sh
nixos-install --flake "$FLAKE#tleilax" --no-root-passwd
```

There are no passwords on the installed system. Root is locked, and
`kabilan` logs in only with the YubiKey SSH keys. So the console shows boot
messages and asks for the disk passphrase, but you can't log in there.

While it builds, record the keys on **jacurutu**. In `lib/fleet.nix`, under
`hosts.tleilax`, set:

- `hostPubkey`: the first public key from step 6, without the
  `root@tleilax` comment;
- `initrdUnlock.hostPubkey`: the second one, without its comment;
- `initrdUnlock.lanAddress`: `LAN_IP`;
- `ageRecipients`: the two recipients from step 3, if not done yet.

```sh
cd ~/dotfiles
git add lib/fleet.nix
git commit -m "tleilax: record install keys" && git push origin nixos
rebuild
```

After the rebuild, jacurutu trusts the new host key and has two new SSH
aliases, `tleilax-unlock` and `tleilax-unlock-away`. Both pin the boot
environment's key and refuse any other.

In the Tailscale admin console, delete the old `tleilax` machine, so the new
one can take the name.

When `nixos-install` finishes, back in the installer:

```sh
ls /mnt/boot /mnt/boot/extlinux   # config.txt, u-boot.bin, start4.elf, extlinux.conf, nixos/, initrd-ssh/
swapoff /mnt/swapfile 2>/dev/null; rm -f /mnt/swapfile
umount -R /mnt
cryptsetup close cryptroot
poweroff
```

Remove the installer SD card. Keep it for recovery.

## 8. First boot and unlock

Power on. The HDMI console shows u-boot, a short boot menu, the kernel, then
the passphrase prompt for `cryptroot`. The boot environment also starts SSH
on port 2222 of `LAN_IP`. Unlock either way:

- **On the console:** type the passphrase.
- **From jacurutu at home:** `ssh tleilax-unlock`. Touch the YubiKey, and the
  session shows the passphrase prompt and nothing else. It closes once the
  disk opens and boot continues.
- **From jacurutu away from home:** `ssh tleilax-unlock-away`. That logs into
  sietch first (one touch), then jumps to the Pi's LAN address (a second
  touch). sietch only forwards the encrypted connection. The laptop checks the
  Pi's boot key end to end, and sietch has no key the Pi accepts.

**Unverified:** that the Pi's Ethernet and the USB SSD come up in the boot
environment with the modules in `machines/tleilax/hardware.nix`. All of them
exist in the pinned kernel, but none has run on this Pi. If the prompt never
appears on the console, see step 12.

**Unverified:** that the jump works with sietch's `RequestTTY=yes` and
connection sharing, and with Mullvad active on sietch. If it fails, try
`ssh -o ProxyCommand='ssh -o RequestTTY=no -W %h:%p sietch' tleilax-unlock`.

After the unlock, tleilax logs into Tailscale with the first-boot key. From
jacurutu:

```sh
tailscale status | grep tleilax
```

It should show `tleilax` tagged `tag:credentials`. If its address isn't
`100.73.84.103`, set it back in the admin console (the machine's menu, Edit
IPv4 address). **Unverified:** that the console lets a new node take a deleted
node's address. Otherwise put the new address in `lib/fleet.nix`
(`tailscaleIp`) and in the policy's `hosts`, paste the policy, and rebuild
jacurutu.

Then log in and check it:

```sh
ssh tleilax
sudo rm /var/lib/tailscale/first-boot-auth-key
systemctl --failed
sudo cryptsetup status cryptroot | grep -i cipher
tailscale status --self
```

Check the agent key's limits from jacurutu. The first command should print
the Pi's tmux sessions as JSON. The second should be refused by `deploy-gate`.

```sh
ssh tleilax-agent '"$HOME/bin/sessionizer" --inventory'
ssh tleilax-agent id
```

## 9. Hark alerts (jacurutu)

Failed units on tleilax post to Hark under the project "Fleet". The webhook
belongs to a Hark service integration of its own, encrypted for tleilax and
the two YubiKeys only. Until the file exists, alerts are off.

Create the integration with `harkctl` and encrypt its curl config. The
webhook URL is the secret, so it goes to files, never to the terminal:

```sh
umask 077
d=$(mktemp -d)
harkctl services list
harkctl services create --title "tleilax alerts" > "$d/service.json"
url=$(jq -r .webhookUrl "$d/service.json")
case $url in
https://hark.sole-pierce.ts.net/hooks/*) printf 'url = "%s"\n' "$url" > "$d/tleilax-alerts.curl" ;;
*) echo "unexpected webhook URL; stop here" ;;
esac
unset url
cd ~/dotfiles
EDITOR="cp $d/tleilax-alerts.curl" agenix -e secrets/hark/tleilax-alerts.curl.age
rm -rf "$d"
```

`harkctl services list` is there so you don't make a second integration if
one already exists. Creating one isn't idempotent.

Check that each YubiKey can decrypt it without printing it. Each asks for
the PIV PIN and a touch:

```sh
agenix -d secrets/hark/tleilax-alerts.curl.age -i ~/.config/age/yk-nfc.txt > /dev/null && echo yk-nfc ok
agenix -d secrets/hark/tleilax-alerts.curl.age -i ~/.config/age/yk-nano.txt > /dev/null && echo yk-nano ok
```

Plug in the matching key for each line.

Commit and push it:

```sh
git add secrets/hark/tleilax-alerts.curl.age
git commit -m "tleilax: Hark alert webhook" && git push origin nixos
```

The first deploy (step 10) turns the alerts on.

## 10. First deploy (jacurutu)

```sh
deploy tleilax
```

tleilax has no signed tag yet, so `deploy` lists the last 20 commits on
`nixos` and asks. It signs and pushes a tag (PIN and touch, twice), then
starts the receiver on tleilax over `tleilax-agent`. tleilax fetches GitHub,
checks the signature, builds the commit itself and switches. The commits
from steps 7 and 9 descend from the installed one, so the receiver accepts
them. Expect the build to take a while.

Test the alert path afterwards. This posts a fake failure for a unit named
`runbook-test.service`:

```sh
ssh tleilax 'sudo systemctl start fleet-alert@runbook-test.service'
```

It should show up in Hark under "Fleet". **Unverified:** that Hark creates
the "Fleet" project from the first webhook payload that names it.

## 11. Test an unlock at a reboot

```sh
ssh tleilax 'sudo systemctl reboot'
ssh tleilax-unlock
```

Try `tleilax-unlock-away` once too, ideally from outside the home network.

## 12. Rollback and recovery

**Before the wipe (steps 1 to 5)** nothing on the Pi has changed.

**If the old system lived on the SD card** and you kept that card, rollback
is: power off, unplug the SSD, put the old card back. The Pi boots the old
system. Its config is in git at the commit before this PR, in `raspi/`.

**If the old system lived on the SSD**, step 6 erased it. To bring it back,
boot the installer and build the old SD image there:

```sh
nix build "github:Kabilan108/dotfiles/420c852e70cde8570d8c7e91b3e41d8128b1f533?dir=raspi#nixosConfigurations.tleilax.config.system.build.sdImage"
```

That hash is the last `nixos` commit with `raspi/`. The image lands under
`result/sd-image/`. Flash it to an SD card as in step 5.

**If the new system doesn't boot**, find where it stops on the HDMI console:

- **Nothing on screen, or the rainbow screen only.** The firmware didn't find
  the boot partition or u-boot. Boot the installer, mount the SSD (below) and
  check that `config.txt`, `u-boot.bin`, `start4.elf` and
  `bcm2711-rpi-4-b.dtb` are on it. If they are, the EEPROM may not boot from
  USB or read GPT. Update it from Raspberry Pi OS on a spare SD card
  (`sudo rpi-eeprom-update -a`).
- **u-boot runs but finds nothing to boot.** Check `extlinux/extlinux.conf`
  on the boot partition.
- **The kernel starts but never asks for the passphrase**, or SSH on port 2222
  never answers. A boot-environment module is missing, or the key copy
  failed. Fix the config on jacurutu, then reinstall from the installer
  (below).
- **A later generation is broken.** At the u-boot menu, pick an older one
  with the keyboard. Then `deploy --allow-rollback tleilax` to an older
  commit, or fix forward with a normal deploy.

**Mount the installed system from the installer:**

```sh
sudo -i
export NIX_CONFIG="experimental-features = nix-command flakes"
FLAKE=github:Kabilan108/dotfiles/<full commit hash>
mount=$(nix build --no-link --print-out-paths "$FLAKE#nixosConfigurations.tleilax.config.system.build.mount")
"$mount/bin/disko-mount"         # asks for the passphrase
nixos-enter --root /mnt -c 'journalctl -b -1 --no-pager | tail -200'
```

To reinstall after a fix, mount as above and run `nixos-install --flake
"$FLAKE#tleilax" --no-root-passwd` again with the new commit. The host keys,
the firmware and the boot key stay where step 6 put them.

**If tleilax never joins the tailnet**, you can't log in: there is no console
login and no SSH on the LAN. Mount it from the installer as above, read
`journalctl -u tailscaled -u tailscaled-autoconnect` through `nixos-enter`,
and write a fresh auth key to `/mnt/var/lib/tailscale/first-boot-auth-key` if
the first one expired or was used up.

## Unverified

- That this Pi's EEPROM boots from USB and reads GPT (steps 1 and 12).
- Whether removing `tag:server` as auto-approver revokes sietch's existing
  approval for `svc:vault` and `svc:executor` (step 4).
- The Hydra jobset name for the aarch64 installer image (step 5).
- That Ethernet and the USB SSD come up in the boot environment, and that the
  boot key copy runs before sshd (step 8). The module names were checked
  against the pinned aarch64 kernel, not on the Pi.
- That u-boot reads the T5 over USB. The NixOS SD image uses the same u-boot,
  but this layout puts it on the SSD.
- The `ssh -J sietch` jump with sietch's SSH settings and Mullvad (step 8).
- That the admin console lets the new node reuse `100.73.84.103` (step 8).
- That Hark creates the "Fleet" project from the first alert (step 10).
- Nothing in this file has been run end to end.
