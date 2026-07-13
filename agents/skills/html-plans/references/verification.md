# Verification

## Content

- Re-check file, commit, command, metric, and behavioral claims against their sources.
- Mark unavailable evidence and incomplete collection.
- Scan for tokens, credentials, cookies, private environment values, and accidental raw logs.

## Rendering

- Open the artifact and check the browser console.
- Test desktop and narrow widths; no clipped tables, code, diagrams, or navigation.
- Exercise controls, reset, copy/export, anchors, and links.
- Check keyboard focus, contrast, reduced motion, and print where relevant.

## Publication

Use `pagebin publish ... --verify --json` for the initial publication and `pagebin update <file> --json` for revisions. `pagebin verify` must report matching hashes. Keep the stable URL. Publication success and artifact completeness are separate outcomes.
