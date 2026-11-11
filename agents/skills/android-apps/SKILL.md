---
name: android-apps
description: Use when building, signing, emulator-testing or installing an Android app (native Kotlin or React Native) for Tony's phone, or when pairing or connecting to it over wireless ADB.
---

# Android apps on Tony's phone

Tony's phone is a Pixel 9. Phone builds happen on sietch, which holds the SDK,
the AVDs, the signing key and the ADB pairing. The SDK reaches agents through
T3 Code's service environment (`~/dotfiles/home/services/t3-code.nix`): it sets
`$ANDROID_HOME` and puts `adb`, `emulator` and JDK 17 on PATH. Login shells
outside T3 have no SDK. `apksigner` is at `$ANDROID_HOME/build-tools/<version>/`.

The port scanner and install script live in
`~/dotfiles/agents/skills/android-apps/scripts/`.

## Build

- Run Gradle through the project devshell: `direnv exec <repo> ./gradlew ...`.
  Write output to a file and check the exit code
  (`... > /tmp/<app>-build.log 2>&1; echo exit=$?`).
- NixOS quirks the devshell or `gradle.properties` must handle: Maven's
  `aapt2` does not run on NixOS, so set
  `android.aapt2FromMavenOverride=$ANDROID_HOME/build-tools/<version>/aapt2`;
  set `android.builder.sdkDownload=false` because the SDK is read-only.
  `/vault/repos/koma/flake.nix` and `gradle.properties` are a working example.
- Install the `release` variant on the phone unless Tony asks for another.

## Signing

Everything destined for the phone is signed with the personal keystore at
`$ANDROID_PERSONAL_KEYSTORE`, which is `~/.android/personal.keystore` (agenix
secret `secrets/android/personal-keystore.age` in `~/dotfiles`; store and key
password `android`, alias `androiddebugkey`). Every app on the phone carries
this signature, and an update installs over an app only when it is signed with
the same key.

Processes started before the variable existed, T3 Code's among them, may lack
it. A devshell can default it to that path, as Koma's `flake.nix` does.

- Native projects: a `release` signing config that reads the path from the
  environment variable and fails the build when it is missing. Koma's
  `app/build.gradle.kts` is the example.
- Generated `android/` directories (Expo prebuild): pass
  `-Pandroid.injected.signing.store.file=$ANDROID_PERSONAL_KEYSTORE`, plus
  `...store.password`, `...key.alias` and `...key.password`, or re-sign the APK
  with `apksigner sign --ks "$ANDROID_PERSONAL_KEYSTORE"`.
- Check every APK before it goes near the phone:
  `apksigner verify --print-certs <apk>` must print certificate SHA-256
  `1994d3271fddd56f15f433fda4b0a71a19cb3699f872a215daac22561afec378`.
- A signature mismatch on install (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`) means
  the wrong key. Rebuild with the right one. Uninstalling or clearing data
  wipes Tony's app data: do it only when he explicitly says so.

## Data safety

Once an app with local data is on the phone, every schema or storage change
ships with a real migration (Room, SQLite, AsyncStorage or MMKV formats) and a
test that runs it. A destructive migration or an in-place schema edit wipes
Tony's data.

## Done means seen on the emulator

- Anything the user sees or touches runs on the emulator before it is called
  done. Unit tests alone have missed real UX bugs (dropped taps, a broken back
  animation).
- **Demo first.** Before an app's first install on the phone, and before
  installing a substantial UX change, record a captioned walkthrough on the
  emulator and send it to Tony (the path in chat, or a `notify` message when
  he is away). Install only after he has seen it.
- Emulator driving, demo recording and device checks are long and produce
  screenshots and logs. Hand them to a delegate with a bounded brief: the APK
  path, its own AVD copy, the flows to exercise, and what to return (pass or
  fail per flow, the video path). Point it at `references/emulator.md`. The
  lead keeps integration, the phone install and the final report.

## Reaching the phone

Resolve the phone through the `fleet` skill: device `tko-pixel-9` in
`~/.config/fleet/fleet.json`, reachable as `tko-pixel-9` on the tailnet.

- Wireless debugging needs Wi-Fi and turns itself off. When the APK is ready,
  ask Tony to turn on **Developer options → Wireless debugging**, and install
  once he confirms. Keep any wait short (minutes); a watcher left polling for
  hours gets killed at its time limit, and he may be asleep.
- The connect port changes every time debugging is toggled, and
  `adb mdns services` finds nothing here. `scripts/adb-scan.py <host>` lists
  open ports in 30000-49999; `phone-install.sh` tries each one. Asking Tony for
  the "IP address & Port" on the Wireless debugging screen also works.

### Pairing

sietch is already paired. A port that connects but shows `unauthorized`, or
none that accepts, can mean pairing is lost. Pair by QR:

1. Record the open ports: `baseline=$(scripts/adb-scan.py tko-pixel-9)`.
2. Generate a random name and password, and render
   `WIFI:T:ADB;S:studio-<name>;P:<password>;;` with
   `nix-shell -p qrencode --run "qrencode -o <file>.png '<payload>'"`.
3. Start a bounded loop (about five minutes) that runs
   `scripts/adb-scan.py tko-pixel-9 $baseline` and, for each new port,
   `adb pair tko-pixel-9:<port> <password>` until one succeeds.
4. Show Tony the QR. He taps **Pair device with QR code** and scans it.
5. Delete the PNG and drop the password once pairing succeeds.

Use the QR flow every time. The six-digit pairing-code dialog closes as soon
as Tony leaves Settings to send the code, so the code is dead on arrival.

## Install and verify

```sh
scripts/phone-install.sh tko-pixel-9 <apk> <package> <activity>
```

It finds the connect port, runs `adb install -r`, prints `versionName`,
`versionCode` and `lastUpdateTime` from `dumpsys package`, launches the
activity with `am start -W`, and exits 0 only when the process is alive and
the crash buffer is empty. Confirm the version and update time are the new
build's, then report "installed and launched", with the version.
