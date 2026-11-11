# Browser and artifacts

Use an integrated browser when one is available and suitable. Otherwise use agent-browser for isolated headless browsing. Use helium-browser-use when the task calls for an intentionally shared Helium session or its saved logins. Use agent-browser for Electron and other CDP targets.

## Temporary: Git submodule RCE (CVE-2026-111760), until git >= 2.56.1
The system git (2.56.0) has a bug where a malicious repo can run code through its submodules. Until this note is removed:
- Never use `git clone --recurse-submodules` / `--recursive`, `git submodule update` / `init` / `sync`, or `git pull` / `fetch` / `checkout` with `--recurse-submodules` on any repo Tony doesn't own.
- Clone untrusted repos with a plain `git clone` (no submodules). If submodules are truly needed, stop and ask Tony first.
- Don't set `submodule.recurse=true` or change git config to enable it.
