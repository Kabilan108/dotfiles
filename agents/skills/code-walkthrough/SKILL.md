---
name: code-walkthrough
description: Guide a visible, verified source or Git-diff walkthrough in Neovim with Terminal Control and Navi, optionally using Diffview, OBS recording, or retained terminal evidence. Use when the user wants an agent-led code tour, code-along, commit or branch diff review, live source explanation, or recorded terminal walkthrough.
---

# Code Walkthrough

Use a **verified tour**: establish the real code and output first, then guide attention through one immutable Navi tour.

## Prepare The Session

1. Confirm `termctrl`, Neovim 0.10 or newer, and `navi.nvim` are available.
2. Start Neovim in the project root as a visible foreground session:

   ```bash
   termctrl run walkthrough -- nvim
   ```

3. Use Terminal Control from another process to inspect and drive that same session. Prefer `interact` through the Terminal Control MCP when available; otherwise use `termctrl show`, `termctrl send`, and `termctrl wait`.
4. Resize before composing the tour if the visible terminal is too narrow. Keep the size stable while presenting or recording.

The session is ready when the human and agent see the same settled Neovim screen and the agent can inspect it through Terminal Control.

## Establish The Journey

1. Ask what the viewer should understand or be able to explain afterward when the outcome is unclear.
2. Read the relevant code and run the narrowest command that proves its current behavior.
3. Inspect the actual visible result. Do not write notes from an expected or remembered result.
4. Choose one conceptual journey. A useful journey often moves from public behavior to the mechanism that produces it, then to the observed result.

Do not combine an overview, failure diagnosis, implementation tour, and fix into one sequence. The journey is established when each planned stop is necessary to answer one coherent question.

## Author One Immutable Tour

Create a JSON file outside the source tree when the tour is temporary. Use literal patterns when they are unique and stable; use line numbers only when exact positions are the point. A stop without an end anchor selects one line; `end_pattern` or `end_line` selects the complete inclusive range.

```json
[
  {
    "file": "src/example.test.ts",
    "pattern": "it(\"updates subscribers\"",
    "end_pattern": "expect(runs).toBe(2)",
    "message": "The public contract starts here: one write must cause one additional run."
  },
  {
    "file": "src/example.ts",
    "pattern": "export function notify",
    "end_pattern": "subscriber()",
    "message": "The implementation reaches every subscriber through this loop."
  }
]
```

Load it without modifying it:

```vim
:NaviLoad /absolute/path/to/tour.json
```

Apply these rules:

- Create at most one tour per assistant response.
- Treat a shown tour as immutable. Do not rewrite its stops or notes in the same response.
- Start at the behavior or call site before entering implementation details.
- Use one range stop for adjacent lines that form one simple mechanism.
- Use multiple stops only for a genuine journey between distinct locations.
- Put most of the explanation in short, casual Navi notes; keep chat brief.
- Keep concise verified output at the decisive assertion or result when it helps explain the behavior.
- If verification disproves the explanation, stop and say so. Clear or replace the tour only in the next response.

The tour is complete when every stop resolves, the first stop is visible, and its notes agree with the verified code and output.

## Present The Tour

Let the viewer control the pace unless asked to drive:

```text
Tab        next stop
Shift-Tab  previous stop
p          pick a stop
q          clear the tour
```

These mappings may be configured to exist only while a tour is active. If they are unavailable, use `:NaviNext`, `:NaviPrev`, `:NaviPick`, and `:NaviClear`.

Oversized source ranges may start with their internal folds recursively closed so the annotation remains visible. Let the viewer use `zo` or `zO` to reveal the structures they want to inspect. Diffview tours remain unfolded.

Pause for questions without replacing the active tour. A follow-up explanation may focus the current range or inspect output, but a different conceptual journey belongs in a later tour.

## Walk Through A Diff

Resolve the comparison before writing notes:

```bash
git rev-parse --verify '<base>^{commit}'
git diff --no-ext-diff --find-renames --histogram <base> <target> -- <paths>
```

For a commit or branch target, resolve it separately with `git rev-parse --verify '<target>^{commit}'`. For tracked worktree changes, use the sentinel `WORKTREE` in the tour specification and omit the target from the inspection command:

```bash
git diff --no-ext-diff --find-renames --histogram <base> -- <paths>
```

Never switch the user's branch or disturb a dirty worktree to prepare a review.

Inspect the complete diff, then select only the hunks needed for one conceptual explanation. Prefer exact commit SHAs in the retained specification. Create a diff-tour JSON object with repository-relative paths:

```json
{
  "repo": "/path/to/repository",
  "base": "base-sha",
  "target": "target-sha",
  "stops": [
    {
      "file": "src/example.ts",
      "pattern": "export function changed",
      "end_pattern": "return result",
      "base_pattern": "export function old",
      "base_end_pattern": "return oldResult",
      "message": "This range is the changed mechanism."
    }
  ]
}
```

```vim
:NaviDiffviewLoad /absolute/path/to/diff-tour.json
```

- Use Diffview for side-by-side source with native add, change, delete, and character-level highlighting. Anchor the annotated side with the normal source fields. Add `"side": "base"` to explain removed code; the default side is `"target"`.
- For a mixed replacement, keep the note on the target side and add `base_pattern`/`base_end_pattern` or `base_line`/`base_end_line`. Navi then focuses the corresponding base and target ranges together.
- Do not combine `"side": "base"` with `base_pattern` or `base_line`; dual-range base anchors are valid only when the annotated side is the target.
- Leave the Diffview file panel hidden initially. The viewer can reopen it when file navigation is more useful than comparison width.
- Preserve Git's diff colors. Navi's focus treatment should identify the current range without replacing add/delete/change backgrounds.
- Verify every stop in Diffview. Return the tour to stop one before handing control to the viewer.

## Record With OBS

Use OBS when the desired artifact is the human-facing presentation, including natural pacing, narration, window chrome, or other visual context.

1. Add a Window Capture source for the terminal window containing `termctrl run`.
2. Crop unrelated tabs, prompts, notifications, and private paths before recording.
3. Set the terminal size, font size, OBS canvas, and capture crop before authoring the tour so notes wrap exactly as they will in the recording.
4. Perform a short test recording. Verify text legibility, microphone level, terminal contrast, and that Navi notes fit without clipping.
5. Start OBS recording, present the immutable tour, then stop recording after the final frame has held long enough to read.

OBS is the primary recording in this branch. Terminal Control remains the agent-control and verification surface.

## Retain Terminal Evidence

Use Terminal Control artifacts when the user wants a terminal-native replay, a screenshot, or debugging evidence rather than a full OBS presentation.

- Capture the current screen at any time with `termctrl save walkthrough --format png --out artifacts/current`.
- Recording must be enabled when the session starts; it cannot currently be added to an already-running foreground session.
- For a terminal-native recording, restart deliberately with `--record` before presenting:

  ```bash
  termctrl run walkthrough --record artifacts/walkthrough.termctrl -- nvim
  ```

- Add markers at meaningful moments, then inspect or export the recording after the session ends:

  ```bash
  termctrl mark walkthrough contract
  termctrl mark walkthrough mechanism
  termctrl markers artifacts/walkthrough.termctrl
  termctrl video artifacts/walkthrough.termctrl --out artifacts/walkthrough.mp4
  ```

Do not record or retain terminal input, source, paths, or output that may contain secrets unless the user explicitly needs that artifact.

## Finish

Clear the tour and stop the session unless the user wants it left open:

```vim
:NaviClear
```

```bash
termctrl stop walkthrough
```

Report the verified behavior, the journey presented, and any retained artifact paths. The walkthrough is complete when the viewer has traversed the journey, the terminal session has the requested final state, and every promised artifact has been checked.

## Tool References

- Terminal Control: <https://github.com/anomalyco/terminal-control>
- Navi: <https://github.com/kitlangton/navi.nvim>
