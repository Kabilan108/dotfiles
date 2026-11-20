# Receivers start deploys through a root broker socket and record each run by job ID

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The host's user, and agent keys through `deploy-gate`, need to start `deploy-receiver.service`. A polkit rule allowing "start" on that unit would also allow `--job-mode=flush`, because systemd doesn't pass the job mode to polkit. systemd unloads a finished oneshot unit and forgets its Result, so a caller that polls the unit can't learn how its run ended. Activation during a deploy can restart systemd and disconnect a `systemctl` query. Job IDs restart at boot. The switch a receiver runs must not stop or restart the receiver.

## Decision

- The `deploy-trigger` socket (`/run/deploy-trigger.sock`, mode 0660, group `deploy-trigger`, `Accept=true`, `MaxConnections=4`) runs `deploy-trigger-broker` as root once per connection, for at most `RuntimeMaxSec=30`. The broker reads nothing from the caller. It calls `StartUnit` with job mode `replace` without waiting, replies with the job ID and exits. `StartUnit` returns the job it queued or the pending job it joined, so the ID names the run that serves the request. A caller that never reads can't hold a connection slot, and the receiver never depends on the caller.
- `deploy-receiver-run` is the unit's `ExecStart`. It wraps the receiver and writes `<job> <invocation id> started` and `<job> <invocation id> exit:<status>` to `/run/deploy-receiver/runs`, keeping the last 100 lines. The file is under `/run` because job IDs are per boot.
- `deploy-trigger` follows the record for its job. A failed `systemctl list-jobs` counts as still pending, since only a successful query can show the job is gone. Once the job is gone it reads the record once more, because the exit record is written before the job ends.
- `deploy-receiver.service` sets `restartIfChanged = false` and `X-StopOnRemoval = false`, as nixos-upgrade does.
- `deploy` starts each receiver in the background over ssh. The deploy goes on on its host whatever happens to the controller's session.
- `tests/deploy-trigger.nix` checks this with a stand-in receiver. When `/run/noisy-deploy` exists it writes 20000 debug lines, far more than a socket buffer holds, then keeps running for 5 s, so a broker that streamed the log to a client that never reads would block. `queued.service` waits behind a 600 s `blocker.service` so the test can confirm the job stays queued after triggers; a final control runs a `--job-mode=flush` start and confirms that does cancel the queued job, so the earlier checks could have seen it. `MaxLevelConsole` is forced to `info`, since debug lines would go to the VM's slow serial console and hold journald back. The test asserts `/run/fleet-switch.lock` is `root:root 600` and that `kabilan` cannot take it.

## Consequences

- Moving to polkit would need systemd to expose the job mode to polkit rules.
- The broker must keep reading nothing from the caller.
- Run records do not survive a reboot.
- Removing the flush control would let the queue check pass vacuously.

## Where

- `modules/nixos/deploy/default.nix` (`systemd.sockets.deploy-trigger`, `systemd.services."deploy-trigger@"`, `systemd.services.deploy-receiver`, `runsFile`)
- `modules/nixos/deploy/broker.sh`
- `modules/nixos/deploy/run-record.sh`
- `modules/nixos/deploy/trigger.sh` (`job_pending`, `run_record`)
- `modules/nixos/deploy/deploy.sh` (`start_receiver`)
- `tests/deploy-trigger.nix` (`stand-in-receiver`, `blocker`, `queued`, `testScript`)
