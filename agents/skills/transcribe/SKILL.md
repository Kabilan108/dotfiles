---
name: transcribe
description: Transcribe audio or video through Siren. Use when a task needs speech-to-text or an existing transcript job resumed or inspected.
---

# Transcribe

Use `siren-transcribe`. Run it without arguments for its current commands,
input guidance, and recovery workflow. Prefer it over raw HTTP because it
checks for an audio stream before upload and records accepted jobs locally.

Siren runs on the sietch machine in the fleet and is available within the
tailnet at `https://siren.sole-pierce.ts.net`. Use the existing host-managed
credentials. Keep API keys out of commands, output, and files.
