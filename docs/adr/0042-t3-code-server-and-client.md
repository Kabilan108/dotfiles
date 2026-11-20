# Home Manager owns the T3 Code server on sietch; jacurutu runs only the client

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

T3 Code ships a native `t3` binary with its own updater and an optional upstream service. T3's Android tooling expects the Android Studio SDK layout (`cmdline-tools/latest`), while Nix installs command-line tools by version.

## Decision

- `t3-code.service` is a Home Manager unit; `t3-update` runs `t3 update` without installing the upstream service.
- After an update, `t3-update` compares the running executable with the installed symlink and restarts on a mismatch, which also catches an earlier update that downloaded a release without restarting.
- The SDK wrapper adds a `cmdline-tools/latest` symlink and fails the build without `avdmanager`. `~/Android/Sdk` exposes the conventional path to tools outside the service.
- jacurutu installs only the desktop client from the AppImage; the server runs on sietch. Its icon is the official Linux production icon, vendored from pingdotgg/t3code at 69db400b3cd6b1590d0dfdabf9857621a9089b39.

## Consequences

Installing the upstream service would give two units fighting over port 3773. A new icon upstream needs a manual re-vendor.

## Where

- `home/services/t3-code.nix` (`androidSdkPackage`, `t3Update`, `home.file."Android/Sdk"`)
- `machines/jacurutu/default.nix` (`programs.appimages.apps.t3code`)
