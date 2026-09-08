# Prompt quick reference

Use a line when it resolves an ambiguity. Keep the rest conversational.

| Situation | Optional addition |
|---|---|
| Investigation before implementation | Audit and recommend; leave the implementation unchanged for my review. |
| Local implementation | Implement through verified local changes. I will deploy. |
| Human review boundary | Prepare the review artifact and handoff; pause when human review is the remaining dependency. |
| Delegation | Use Sol at medium for the bounded implementation. Review and integrate its work yourself. |
| Design uncertainty | Challenge the design before implementation. Ask about decisions the repo cannot settle. |
| HTML communication | Make this an HTML report. Choose the design freely; keep the evidence easy to inspect. |
| Resume work | Pick up from this handoff. Preserve earlier decisions and approvals; check the current branch and running jobs. |
| Review scope | Review this change for behavioral defects. Probe material suspicions where useful, and separate confirmed issues from unresolved concerns. |
| Verification cost | Use the smallest reliable checks for the changed behavior. Explain any expensive check before running it if it materially changes the budget. |

Good questions are welcome. State a stopping boundary where it matters; routine choices can stay with the agent.
