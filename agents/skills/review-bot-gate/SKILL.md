---
name: review-bot-gate
description: Triage and resolve automated PR review-bot comments (Greptile or similar) before merging. Use when a PR has bot review comments, when a repo's conventions require the review gate, or when asked to handle review bot findings.
---

# Review Bot Gate

A PR with an automated reviewer attached does not merge until every bot
comment is resolved: fixed or dismissed with evidence. Not every repo has a
bot configured — when none is present, this gate simply does not apply.

## The loop (cap at 2 rounds unless told otherwise)

1. Wait for CI AND the bot review to complete. Poll the specific PR:

```bash
gh pr checks <n>
gh api repos/<owner>/<repo>/pulls/<n>/comments \
  --jq '.[] | select(.user.login | test("greptile";"i")) | select(.in_reply_to_id == null)'
```

2. **Triage every comment** as true or false positive. Verify claims against
   reality before accepting OR dismissing: read the pinned dependency source,
   run the test the comment says should fail, check the actual behavior.
   Review bots are right often enough to take seriously and wrong often
   enough to check.
3. **True positives**: fix, commit, push. Reply on the thread naming the fix
   commit.
4. **False positives**: reply with cited evidence — a source file:line, a
   stdlib/dependency semantic, or a passing test that contradicts the claim.
   Never dismiss with bare assertion.
5. Re-check after the push; new comments start the next round. Terminate when
   CI is green and no unresolved comments remain, or the round cap is hit
   (then summarize what remains for the user).

## Known noise

- CodeRabbit "fail" status from its own rate limiting is not a code finding.
- Comments predicting a test failure that CI's green run already disproves
  are false positives by construction — cite the run.
- Style suggestions that contradict repo conventions lose to the repo.

## Discipline

- Address the finding, not the badge: a P1 can be wrong and a P2 can be a
  real production bug (both have happened).
- If a bot finding reveals the docs promised something the code never did,
  prefer fixing the code to weakening the docs when the promise is the
  feature's purpose.
