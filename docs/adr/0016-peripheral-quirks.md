# Audio and input devices get targeted fixes for observed misbehaviour

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

- Bluetooth headsets drop to a low-quality headset profile when an app opens the microphone; calls use a separate microphone.
- The Framework 13 airplane key emits `KEY_RFKILL` directly to the kernel.
- The MX Master 2S thumb button triggers dictation. Gesture navigation in its firmware fallback suppressed pointer movement when the switch stuck.

## Decision

- WirePlumber sets `bluetooth.autoswitch-to-headset-profile = false` to keep high-fidelity playback.
- A hwdb rule maps the airplane key's measured HID scan code (`100c6` on `evdev:input:b0018v32ACp0006*`) to `reserved`, leaving the other hotkeys alone.
- Solaar's startup script diverts button 195 to HID++ notifications and reprograms its firmware fallback to 196, which has no gesture navigation.

## Consequences

A different keyboard or mouse needs its own scan code or button IDs.

## Where

- `configuration.nix` (`services.pipewire.wireplumber.extraConfig."51-bluetooth"`)
- `machines/jacurutu/default.nix` (`services.udev.extraHwdb`)
- `home/services/solaar.nix` (`configureMouse`)
