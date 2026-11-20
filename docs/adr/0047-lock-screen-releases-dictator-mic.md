# Release Dictator's microphone while the screen is locked

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Dictator keeps its microphone open while the session is unlocked. Leaving it open behind the lock screen is unwanted, but a failing or hung Dictator must never stop the screen from locking.

## Decision

When `services.dictator` is enabled, `lock-screen` runs `dictator mic release` before swaylock and traps EXIT to run `dictator mic resume`. Each call is wrapped in `timeout 3`, discards output, and ends in `|| true`.

## Consequences

Locking proceeds within about 3 seconds even if Dictator is unresponsive. The microphone resumes whenever the script exits, including on swaylock failure.

## Where

- `home/desktop/wayland/swaylock.nix` (`dictatorMic`, `lockScreen`)
