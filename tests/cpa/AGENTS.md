# CPA test notes

`README.md` describes each check. These are the upstream behaviors the checks work around.

- The legacy-config control run deletes `management` before starting CPA without preStart, because CPA refuses to start on `management: null`.
- Traversal checks on the models front accept 400, 401 or 404. CPA routes `/v1/models/*model`, so a dot-segment path under it reaches inference auth and returns 401; the check that matters is that no management data comes back.
- In `browser.sh`, navigate with the dashboard's own links. The dashboard routes by URL hash and ignores an open that changes only the hash.
- Keep `login_with_retry`. A fresh Helium profile holds the page's first requests for about 5 s and then reloads, which drops a login sent in that window.
