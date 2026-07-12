---
name: notify
description: Send the user a Discord notification - use when finishing a long-running job, hitting a blocker that needs human input, or completing significant background work the user is not watching.
---

Send with the `discord-notify` CLI (on PATH on fleet machines; reads
`DISCORD_WEBHOOK_URL` from the environment — `source ~/.bashenv` first if it
is unset):

```sh
discord-notify -t "<short title>" -s <info|success|warning|error> --body "<details>"
```

- `--url <link>` makes the title clickable — point it at the deliverable
  (pagebin plan, PR, artifact) whenever one exists.
- `--field NAME=VALUE` adds inline embed fields (repo, branch, session name);
  host and cwd are attached automatically.
- Match `-s` to the outcome; titles should read well on a phone lock screen.
- Notify once per job at a meaningful boundary, not per step.
