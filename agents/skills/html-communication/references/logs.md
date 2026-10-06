# Logs

A live log shows the state of work as it happens. The user glances at it, so the current state sits at the top: state, active milestone, verification so far, outstanding dependency, next action. Keep those five accurate on every update. Below them: milestones as a timeline, decisions and deviations, blockers. `templates/implementation-log.html` is an optional starting point.

- One identity for the whole run: `pagebin watch` or `pagebin update` on the same artifact.
- Checkpoint meaningful changes before long operations.
- After a restart, rebuild the state from the existing log and the actual run state, then update the log.
- A log records progress; it does not signal that a process finished.
- Recordings, screenshots and command output are the exhibits of a log. Put each next to the milestone it proves.
