# Stillsuit helper script notes

- In `stillsuit-agent-panel`, drop the leading `--posix` loop only once Ghostty stops prepending `--posix` to the command it starts in a new window (Ghostty 1.3 does). `../src/plugins/builtin/agent-panel/tests/run.sh` covers the current behaviour.
- In `stillsuit-clipboard-collector`, keep `cmd_watch` waiting with `waitid(..., WEXITED | WNOWAIT)` and killing the process group before it reaps the child. Once the group leader is reaped its group id can be reused, and the kill could hit an unrelated group.
- The order of `IMAGE_TYPES` after image/png in `stillsuit-clipboard-collector` follows the clipboard capture script in Omarchy (basecamp/omarchy, MIT License). Keep that credit if the list is reworked.
- Leave `stillsuit-workbench` preferring `stillsuit-plugins` from PATH over the source script. The packaged helper carries its Python dependencies (jsonschema); the raw script in a `--source` checkout does not, and fails manifest validation when jsonschema is missing.
