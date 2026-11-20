# scripts notes

- Keep the per-file loop in `statix-check`. prek passes several staged files to one hook run, and statix check accepts one target per invocation. Drop the loop when statix takes several targets.
- Keep the syntax mode of `qml-check` limited to the syntax and syntax.id-quotation categories. qmllint's duplicate-id diagnostics also flag ids in separate implicit delegate scopes, which are not real duplicates, so they stay in the manual `lint` mode. The commit hook therefore misses real duplicate ids; run the manual qmllint hook from `docs/testing.md` to catch them.
