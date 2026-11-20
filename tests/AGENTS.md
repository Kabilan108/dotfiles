# Test notes

## Deploy gate (`test_deploy_gate.py`, `sk-dummy.nix`)

- The deploy gate tests sign with OpenSSH's test-only software security key, built from regress/misc/sk-dummy in the OpenSSH source by `sk-dummy.nix`, in place of a YubiKey. Its signatures carry whatever touch and PIN flags the key file asks for, which is how the tests produce signatures without them.
- Strip spaces from `ps -o ppid=` output before passing it to `ps -p`. `ps` pads PIDs under seven digits with a space, which `ps -p` rejects.

## Deploy trigger VM test (`deploy-trigger.nix`)

- Keep the stand-in receiver's 20000 debug lines and 5 s sleep. That is far more than a socket buffer holds, so a broker that streamed the log to a client that never reads would block and fail the test.
- Keep the final `--job-mode=flush` control. It shows that a flush does cancel `queued.service`, so the earlier "still queued" checks could have failed; without it they pass vacuously.
- Keep `MaxLevelConsole` forced to `info`. Debug lines would otherwise go to the VM's slow serial console and hold journald back.

## Backup VM test (`backup.nix`)

- `services.openssh.enable` is on only because it writes the `authorized_keys` file that the status receiver check reads.
- `alert.nasFreePercent = 100` keeps free space below the threshold on every run, so the test can see the first success alert and the next one stay quiet.
- The `partial` job backs up `/sys/bus/pci/rescan` because it is write-only in sysfs: even root's read fails, so restic exits 3.
- `stale_check()` runs `systemctl reset-failed` before each start because back-to-back starts would trip systemd's start limit.
