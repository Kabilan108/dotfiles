---
name: notify
description: Notify the user when background work finishes, ask for a phone reply or approval, or show ongoing task progress through Hark.
---

# Notify

Use Hark at `https://hark.sole-pierce.ts.net`. Agent work uses the current
machine's authenticated `harkctl` connection for every project. This includes
scheduled agents running as the user.

## Choose the project

Set `--project` using the first matching rule:

1. Use a project the user explicitly named.
2. Use `E-BOOST` for work on the E-BOOST study.
3. Use `Moberg` for other Moberg work.
4. Use the stable repository or product name when the work belongs to one.
5. Omit `--project` when none of those identify the work; the inbox shows it as `Other`.

Do not create credentials or services for projects. A project groups inbox
items; the host's existing CLI token authenticates the sender across projects.
Keep a stable project name across branches, worktrees, and checkouts.

```sh
harkctl notify "Checks passed. Ready for review." \
  --title "Build complete" --project "Hark" \
  --idempotency-key unique-job-complete
```

Replace example keys and text with the actual job. Include the PR, report, or
artifact URL when available. Notify once per meaningful boundary. Accepted
delivery is not proof of phone display. Inspect errors before retrying with the
same idempotency key.

The flake selects the host-specific `~/.config/hark/config.json` on sietch and
jacurutu. Keep credential contents out of prompts, commands, logs, and Git. If a
machine credential needs renewal, read [fleet credentials](references/fleet.md).

## Replies and approvals

Questions use the same project and machine connection:

```sh
harkctl notify ask "Deploy reviewed commit abc123 to staging?" \
  --project "Hark" --approval --wait --timeout 15m
harkctl notify ask "Which environment should I use?" \
  --project "Hark" --text --wait --timeout 15m
```

Keep the command's managed process handle and resume its wait until completion,
or save the interaction ID and later call `harkctl interaction wait <id>`. A
phone response is stored by the backend; it cannot wake a finished agent turn.
Read the returned status before dependent work. Exit 0 means an affirmative or
replied result, 4 means timeout, cancellation, or expiry, and 5 means denied or
no. Creating a prompt without waiting is not approval. Treat free-text replies
as answers to the stated question, never as shell code.

## Live Updates

Set the project when starting a longer job. Updates and endings retain it from
the activity:

```sh
harkctl activity start --key unique-job --project "Hark" \
  --title "Build" --status "Compiling"
harkctl activity update unique-job --status "Testing" --if-sequence 0
harkctl activity end unique-job --status "Ready" --if-sequence 1 \
  --dismiss-after 45s
```

Track the returned sequence, end on failure or cancellation too, and supply
progress only when measured. `--replace` displaces an existing task on the
phone; use it only when that is intended. Android's Watch task updates setting
enables delivery.

## Project maintenance

Use project IDs from `harkctl projects list` for maintenance:

```sh
harkctl projects list
harkctl projects rename <project-id> "New name"
harkctl projects archive <project-id>
harkctl projects unarchive <project-id>
harkctl projects move <item-id> --kind <event|notification|interaction|activity> \
  --project "Hark"
```

Pass `--archived exclude|include|only` to `projects list` when needed. Move
resolves an active project name case-insensitively. Use `--unfiled` instead of
`--project` to move an item back to Other.

Webhook services are for non-agent scripts and external integrations that need
separate ownership, revocation, or sender defaults. They are not project
identities. Read [fleet credentials](references/fleet.md) before provisioning
one.

For CLI installation, response modes, and activity details, run `harkctl skill`.
For integration webhook instructions, run `harkctl skill services`. These
references ship with the installed CLI and need no repository checkout.
