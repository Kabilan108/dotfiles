# Review recipe

Use this for PR, diff, security, or architecture reviews.

- Header: repository, branch/PR, commit range, author if known, files changed, and review basis.
- TL;DR: merge posture and the few facts that determine it.
- Risk map: group files by behavior surface and risk, not alphabetical order.
- Findings: severity, exact file and line, violated contract, user-visible consequence, and a concrete fix direction. Separate blockers from optional improvements.
- Diff snippets: show only enough context to establish the finding; preserve line numbers.
- Coverage: behavior checked, tests run, paths not exercised, and uncertainty.
- Rollout: compatibility, flags, migration, monitoring, and rollback.

Do not turn style preferences into findings. If there are no actionable issues, say so plainly.
