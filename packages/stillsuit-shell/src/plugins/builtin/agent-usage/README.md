# Agent usage plugin

This plugin shows Codex and Claude Code subscription limits across local CLI
profiles. Its helper never modifies the monitored profiles. OAuth tokens stay
inside the collector and never enter QML, process arguments, logs, or the
returned snapshot.

## Account discovery

The configured `homeDir` contributes both ambient profiles:

| Provider | Config directory |
|---|---|
| Codex | `<homeDir>/.codex` |
| Claude Code | `<homeDir>/.claude` |

The collector also scans `shadowRoot`. A directory named `codex--rani` is a
direct `CODEX_HOME`. For `claude--work`, the collector accepts both supported
layouts:

- A direct Claude config directory containing `.credentials.json`.
- A T3Code-style whole home containing `.claude/.credentials.json`.

The second form matches T3Code's `HOME` isolation without treating `HOME` as
Claude's general profile selector. Explicit accounts should use `configDir`
for a direct `CODEX_HOME` or `CLAUDE_CONFIG_DIR`. Use `homeDir` only when the
directory is deliberately a whole CLI home; the collector derives `.codex` or
`.claude` beneath it.

```nix
settings.accounts = [
  {
    id = "claude-work";
    provider = "claude";
    label = "Work";
    configDir = "/home/kabilan/.claude-work";
  }
  {
    id = "codex-lab";
    provider = "codex";
    label = "Lab";
    homeDir = "/home/kabilan/.shadow-homes/codex-lab";
  }
];
```

Profiles that resolve to the same provider and config directory are
deduplicated. Explicit IDs use lowercase letters, numbers, dots, and hyphens.

## Provider probes

- Codex makes a private, short-lived `CODEX_HOME` containing an `auth.json`
  clone with its refresh token removed, blocks token-refresh network requests,
  runs the installed `codex app-server`, and reads `account/read` plus
  `account/rateLimits/read`. App-server state is discarded with the private
  directory, so polling cannot write into, lock, or rotate credentials for the
  monitored profile. If its access token needs renewal, normal CLI use must
  refresh it before usage polling can resume.
- Claude reads `<configDir>/.credentials.json` and calls Anthropic's OAuth
  usage endpoint without following redirects. An expired or absent access
  token is not refreshed by the plugin. Opening Claude Code refreshes the
  CLI-owned sign-in.

The service requests a snapshot when it starts and every five minutes after
that. Opening the panel requests another snapshot; the helper reuses provider
results younger than 30 seconds. The panel refresh button forces a provider
request and bypasses that cache. The bar reads the shared service snapshot and
does not poll on its own.

## Presentation

The bar shows only reporting default Codex and Claude accounts, followed by the
lowest remaining quota among them. Signed-out providers and shadow accounts do
not add marks or affect the bar value. Refreshing keeps the last snapshot
visible until its replacement arrives.

The panel uses a flat account list with large provider marks, account names,
plans, identities, and separators. Limit rows span the account width and use
the provider color. Bars fill from empty to the percentage remaining, so a
shrinking bar means the account is closer to its limit. The provider marks use
the supplied `codex.svg` and `claude.svg` assets.
