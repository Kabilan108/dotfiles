# Meeting artifacts

Pipeline-written meeting notes name the artifacts in frontmatter.

Run `meeting-minutes transcript <meeting-note>` to print the speaker-labeled transcript with timestamps. Add `--json` when the original JSON structure or segment metadata matters. The transcript path is available on Jacurutu and Sietch after synchronization.

Sietch holds the durable MP4 copy at the note's `recording` path. The pipeline removes the Jacurutu copy after a successful transfer. From Jacurutu, use `ssh sietch-agent` when an agent needs to inspect or retrieve the recording.
