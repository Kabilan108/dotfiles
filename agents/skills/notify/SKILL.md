---
name: notify
description: Send the user a Discord notification - use when finishing a long-running job, hitting a blocker that needs human input, or completing significant background work the user is not watching.
---

Send with the `discord-notify` CLI. Channel names come from the agenix-managed
`~/.config/discord-notify/channels.json`; webhook URLs must never appear in
prompts, commands, or output.

```sh
discord-notify --channel <name> -t "<short title>" \
  -s <info|success|warning|error> --body "<details>"
```

- Use `discord-notify --list-channels` when the appropriate channel is not
  already specified. Omit `--channel` to use `default`.
- `--url <link>` makes the title clickable — point it at the deliverable
  (pagebin plan, PR, artifact) whenever one exists.
- `--field NAME=VALUE` adds a readable full-width field. Use
  `--inline-field NAME=VALUE` only for short sibling values such as repo and
  branch.
- Compact notifications show `<host> · <cwd basename>` in the footer. Add
  `--full-context` only when the absolute working directory is useful.
- Match `-s` to the outcome; titles should read well on a phone lock screen.
- Notify once per job at a meaningful boundary, not per step.
