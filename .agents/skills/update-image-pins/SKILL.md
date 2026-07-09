---
name: update-image-pins
description: Check and update digest pins for third-party docker images used by selfhost services on sietch. Use when the user asks to update, bump, or check container images, image pins, or docker digests for self-hosted services.
---

# Update docker image digest pins

Third-party images in `modules/nixos/selfhost/` are pinned by digest:

```nix
image = "<registry>/<name>:<tag>@sha256:<digest>";
```

The tag documents intent; docker resolves the digest. Because the generated
units use `--pull missing`, changing the pin and switching is the entire
update path — no manual `docker pull` or restart. Mutable tags are never
auto-pulled (supply-chain caution; see issue #7 context).

Self-built images (e.g. siren while it was docker-based) are NOT digest-pinned;
they update via local build + `systemctl restart docker-<name>`. Services from
flake inputs update via `nix flake update <input>`.

## Flow

1. Check for drift (skopeo runs via nix shell, no install needed):

   ```sh
   bin/image-pins check
   ```

2. For each drifted image, look up what changed before updating — find the
   project's releases/changelog (e.g. github releases for the repo behind the
   image) and summarize it for the user. Do not blind-bump.

3. Update the pin(s):

   ```sh
   bin/image-pins update            # all drifted
   bin/image-pins update executor   # one image, by substring
   ```

   (Or Edit the `.nix` file directly — the pin line is self-describing.)

4. Validate and apply:

   ```sh
   git add -u
   nix build .#nixosConfigurations.sietch.config.system.build.toplevel --no-link
   ```

   Then ask the user to run: `! sudo nixos-rebuild switch --flake ~/dotfiles#sietch`

5. Verify the service after the switch (unit active + its https endpoint
   responds; see the add-selfhost-service skill for the commands), then commit
   the pin bump with the upstream version/changes noted in the message.

## Adding a pin for a new image

```sh
nix shell nixpkgs#skopeo -c skopeo inspect --format '{{.Digest}}' docker://<registry>/<name>:<tag>
```

Append `@<digest>` to the image string in the service's nix file.
