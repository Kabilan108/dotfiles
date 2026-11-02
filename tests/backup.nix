# VM test for modules/nixos/backup with a local repository in place of the NAS
# share. From the repo root:
#   nix build --impure --expr 'import ./tests/backup.nix { pkgs = (builtins.getFlake "git+file://${toString ./.}").inputs.nixpkgs.legacyPackages.x86_64-linux; }'
{ pkgs }:
pkgs.testers.runNixOSTest {
  name = "backup";
  nodes.machine =
    { lib, pkgs, ... }:
    {
      imports = [ ../modules/nixos/backup ];
      networking.hostName = "testhost";
      users.users.kabilan.isNormalUser = true;
      # Writes the authorized_keys file the status receiver test reads.
      services.openssh.enable = true;
      users.users.svc = {
        isSystemUser = true;
        group = "svc";
      };
      users.groups.svc = { };
      environment.systemPackages = [ pkgs.sqlite ];
      systemd.tmpfiles.rules = [
        "d /srv/svc 0700 svc svc -"
        "d /srv/num 0700 65532 65532 -"
        "d /data/files 0755 root root -"
        "d /data/drexel 0755 root root -"
        "f /var/lib/alerts.log 0666 root root -"
      ];
      dotfiles.backup = {
        enable = true;
        repository = "/srv/restic";
        passwordFile = "/var/lib/backup-password";
        retry = {
          attempts = 2;
          delaySec = 2;
        };
        alert = {
          outputFile = "/var/lib/alerts.log";
          # Always below, so the first success alerts and the next doesn't.
          nasFreePercent = 100;
        };
        statusReceive = [ "sietch" ];
        timer = {
          OnCalendar = "2099-01-01";
        };
        check.timer = {
          OnCalendar = "2099-01-01";
        };
        jobs = {
          files.paths = [ "/data/files" ];
          # Write-only in sysfs, so even root's read fails: restic exits 3.
          partial.paths = [
            "/data/files"
            "/sys/bus/pci/rescan"
          ];
          missing.paths = [
            "/data/files"
            "/data/does-not-exist"
          ];
          services = {
            paths = [
              "/srv/svc"
              "/srv/num"
            ];
            exclude = [
              "/srv/svc/live.sqlite*"
              "/srv/num/data.db*"
            ];
            sqlite = {
              svc = {
                database = "/srv/svc/live.sqlite";
                user = "svc";
              };
              num = {
                database = "/srv/num/data.db";
                user = "65532";
              };
            };
          };
        };
      };
    };
  testScript = ''
    import json

    def alerts():
        lines = machine.succeed("cat /var/lib/alerts.log").splitlines()
        return [json.loads(line) for line in lines if line.strip()]

    def alert_count(text):
        return sum(1 for a in alerts() if text in a["body"])

    def status(job):
        return json.loads(machine.succeed(f"cat /var/lib/backup-status/testhost-{job}.json"))

    def snapshots(tag):
        out = machine.succeed(f"restic-files snapshots --json --tag {tag}")
        return json.loads(out) or []

    def run_to_failure(job):
        machine.fail(f"systemctl start restic-backups-{job}.service")
        machine.wait_until_succeeds(
            f"systemctl show -P ActiveState restic-backups-{job}.service | grep -qx failed", timeout=60
        )
        machine.wait_until_succeeds(
            f"test \"$(systemctl show -P ActiveState backup-alert@restic-backups-{job}.service)\" != activating",
            timeout=30,
        )

    machine.wait_for_unit("multi-user.target")
    machine.succeed("echo REPLACE_ME > /var/lib/backup-password && chmod 0400 /var/lib/backup-password")
    machine.succeed("echo hello > /data/files/note.md && echo secret > /data/files/.hidden")
    machine.succeed("test \"$(stat -c '%U %a' /var/lib/backup)\" = 'root 700'")

    with subtest("the placeholder password blocks the run; retries end in one alert"):
        run_to_failure("files")
        attempts = int(machine.succeed(
            "journalctl -u restic-backups-files.service | grep -c 'still the placeholder'"
        ).strip())
        assert attempts == 3, f"expected 3 attempts, saw {attempts}"
        assert alert_count("The files backup job failed") == 1, alerts()
        assert machine.succeed("systemctl show -P User backup-alert@restic-backups-files.service").strip() == "kabilan"
        assert status("files")["last_result"] != "success"
        assert status("files")["last_success"] is None
        machine.succeed("systemctl reset-failed")

    machine.succeed("echo correct-horse > /var/lib/backup-password")
    machine.succeed("restic-files init")

    with subtest("a backup succeeds and records its status"):
        machine.succeed("systemctl start restic-backups-files.service")
        s = status("files")
        assert s["last_result"] == "success", s
        assert s["last_success"] is not None, s
        assert s["repository_bytes"] > 0 and s["nas_free_bytes"] > 0, s
        assert machine.succeed("stat -c %a /var/lib/backup-status/testhost-files.json").strip() == "644"
        machine.succeed("restic-files ls latest | grep -x /data/files/.hidden > /dev/null")

    with subtest("a threshold alerts when crossed, not on every run"):
        machine.wait_until_succeeds("grep -q 'NAS free space is below' /var/lib/alerts.log", timeout=30)
        machine.succeed("systemctl start restic-backups-files.service")
        machine.sleep(3)
        assert alert_count("NAS free space is below") == 1, alerts()

    machine.succeed("su -s /bin/sh svc -c \"sqlite3 /srv/svc/live.sqlite 'PRAGMA journal_mode=WAL; CREATE TABLE t(v); INSERT INTO t VALUES (42);'\"")
    machine.succeed("setpriv --reuid=65532 --regid=65532 --clear-groups sqlite3 /srv/num/data.db 'CREATE TABLE n(v); INSERT INTO n VALUES (7);'")
    machine.succeed("echo keep > /srv/svc/attachment.bin")

    with subtest("databases are copied by their owners and restore cleanly"):
        machine.succeed("systemctl start restic-backups-services.service")
        listing = machine.succeed("restic-files ls latest --tag services")
        assert "/var/lib/backup-staging/services/svc/live.sqlite" in listing, listing
        assert "/var/lib/backup-staging/services/num/data.db" in listing, listing
        assert "/srv/svc/attachment.bin" in listing, listing
        assert "/srv/svc/live.sqlite\n" not in listing and "/srv/num/data.db\n" not in listing, listing
        machine.succeed("test ! -e /var/lib/backup-staging/services")
        machine.succeed("restic-files restore latest --tag services --target /restore")
        machine.succeed("test \"$(sqlite3 /restore/var/lib/backup-staging/services/svc/live.sqlite 'PRAGMA integrity_check; SELECT v FROM t;' | tr '\\n' ' ')\" = 'ok 42 '")
        machine.succeed("test \"$(sqlite3 /restore/var/lib/backup-staging/services/num/data.db 'SELECT v FROM n;')\" = 7")

    with subtest("a failed export fails the run and a stale copy is never used"):
        before = len(snapshots("services"))
        machine.succeed("mv /srv/svc/live.sqlite /srv/svc/moved.sqlite")
        machine.succeed("install -d -m 0711 /var/lib/backup-staging/services/svc && echo stale > /var/lib/backup-staging/services/svc/live.sqlite")
        run_to_failure("services")
        assert len(snapshots("services")) == before
        machine.succeed("test ! -e /var/lib/backup-staging/services/svc/live.sqlite")
        assert alert_count("The services backup job failed") == 1, alerts()
        machine.succeed("mv /srv/svc/moved.sqlite /srv/svc/live.sqlite")
        machine.succeed("systemctl reset-failed")

    with subtest("an incomplete backup (restic exit 3) is a failure"):
        run_to_failure("partial")
        assert status("partial")["last_exit_status"] == "3", status("partial")
        assert status("partial")["last_success"] is None
        assert alert_count("The partial backup job failed") == 1, alerts()
        machine.succeed("systemctl reset-failed")

    with subtest("a missing source fails the run instead of being skipped"):
        run_to_failure("missing")
        machine.succeed("journalctl -u restic-backups-missing.service | grep > /dev/null 'source /data/does-not-exist does not exist'")
        assert alert_count("The missing backup job failed") == 1, alerts()
        assert len(snapshots("missing")) == 0
        machine.succeed("systemctl reset-failed")

    with subtest("the monthly check passes"):
        machine.succeed("systemctl start restic-backups-check.service")

    with subtest("a one-off archive is tagged for keeps"):
        machine.succeed("echo thesis > /data/drexel/paper.tex")
        machine.succeed("restic-files backup --tag archive /data/drexel")
        assert len(snapshots("archive")) == 1

    with subtest("the status receiver accepts only its host's status"):
        line = machine.succeed("cat /etc/ssh/authorized_keys.d/kabilan | grep backup-status-receive")
        assert 'restrict,from="100.71.183.33"' in line, line
        receiver = line.split('command="')[1].split('"')[0]
        good = json.dumps({"host": "sietch", "job": "files", "last_result": "success"})
        machine.succeed(f"echo '{good}' | su - kabilan -c '{receiver}'")
        machine.succeed("test -s /home/kabilan/.local/state/backup-status/sietch-files.json")
        wrong = json.dumps({"host": "jacurutu", "job": "files"})
        machine.fail(f"echo '{wrong}' | su - kabilan -c '{receiver}'")
        machine.fail(f"head -c 70000 /dev/zero | su - kabilan -c '{receiver}'")
        bad_job = json.dumps({"host": "sietch", "job": "../x"})
        machine.fail(f"echo '{bad_job}' | su - kabilan -c '{receiver}'")
  '';
}
