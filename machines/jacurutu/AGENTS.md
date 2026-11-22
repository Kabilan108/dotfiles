# jacurutu notes

- Keep the explicit `mode` on the 1Password allowed-browsers file and list browsers by executable name (helium, zen, zen-beta, .zen-beta-wrapped). Helium and Zen are not on 1Password's built-in list, the app checks the browser process's executable name, and it rejects the file unless it is root-owned and not a symlink; a mode makes NixOS write a real file.
- The hwdb rule maps scan code 100c6 on `evdev:input:b0018v32ACp0006*` to reserved. The Framework 13 airplane key emits KEY_RFKILL straight to the kernel, and that measured code is the only hotkey the rule touches. Another keyboard needs its own scan code.
- Keep `security.pam.services.login.fprintAuth = false` in `framework.nix`. `services.fprintd.enable` turns fingerprint auth on for `login` by default, and `pam_fprintd` skips `pam_gnome_keyring` so `login.keyring` never unlocks on boot; keeping fingerprint on `sudo`, `polkit-1`, and `swaylock` lets password login on `tty1` unlock the keyring once per session.

## Backup scope (`default.nix`)

- Back up only `/vault/moberg-data/backups` and `/vault/moberg-data/projects` from the Moberg data. The other trees there are recoverable from COS; add one to `paths` if that stops being true.
- Keep the `!<root>/**/.git/**` re-include after the project exclusions. A branch or worktree can share a name with an excluded dependency directory, and the exclusion would otherwise drop Git metadata.
- List each vendored dependency clone under a project root by hand in `exclude`. They are fetched by their projects, but nested source checkouts are otherwise kept on purpose.
