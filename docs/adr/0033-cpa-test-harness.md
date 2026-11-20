# CPA tests account for CPA, nginx and dashboard behavior

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`tests/cpa/run.sh` tests the CPA (CLIProxyAPI) gateway sietch builds; `tests/cpa/README.md` describes the checks. Several of them depend on behavior of CPA, nginx, the dashboard or Helium that is not visible from the test code:

- CPA refuses to start on `management: null`.
- CPA writes logs to `./logs` when that directory exists and is writable, so its working directory matters.
- CPA routes `/v1/models/*model`, so a dot-segment path under it reaches inference auth and returns 401.
- nginx passes `HEAD` through; CPA has no `HEAD` handler for `/v1/models` and answers 404 itself.
- The dashboard routes by URL hash and ignores an open that changes only the hash.
- A fresh Helium profile holds the page's first requests for about 5 s and then reloads, which drops a login sent in that window.

## Decision

- The legacy-config control run deletes `management` before starting CPA without preStart.
- `start_cpa` runs CPA from its state directory, like the unit's `WorkingDirectory`.
- Traversal checks on the models front accept 400, 401 or 404 and check that no management data comes back.
- The `HEAD /v1/models` check accepts 200 or 404 and confirms CPA answered by its `access-control-allow-headers` header.
- The browser check navigates with the dashboard's own links, and `login_with_retry` retries the login once after the reload.

## Consequences

A CPA or dashboard upgrade that changes any of these behaviors shows up as a failing check here first.

## Where

- `tests/cpa/fronts.sh` (`legacy_config_checks`, `start_cpa`, models and admin front checks)
- `tests/cpa/browser.sh` (`login_with_retry`, `browser_checks`)
- `tests/cpa/README.md`
