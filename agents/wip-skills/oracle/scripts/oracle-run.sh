#!/usr/bin/env bash
# Launch a Codex oracle query in the Oracle tmux window.
# Usage: oracle-run.sh <prompt-file> [model] [reasoning_effort]
# Outputs tracking variables: ORACLE_ID, ORACLE_OUT, ORACLE_DONE
set -euo pipefail

PROMPT_FILE="$1"
MODEL="${2:-gpt-5.2-codex}"
REASONING="${3:-xhigh}"
WORKDIR="${PWD}"

ORACLE_ID="oracle-$(date +%s)"
ORACLE_OUT="/tmp/${ORACLE_ID}-output.txt"
ORACLE_DONE="/tmp/${ORACLE_ID}-done"

if [ ! -f "$PROMPT_FILE" ]; then
  echo "Error: prompt file not found: $PROMPT_FILE" >&2
  exit 1
fi

if [ -z "${TMUX:-}" ]; then
  echo "Error: not running inside tmux" >&2
  exit 1
fi

# Ensure Oracle window exists; add a pane if it already does.
# Capture the target pane ID so send-keys hits the right pane.
if ! tmux list-windows -F '#{window_name}' | grep -q '^Oracle$'; then
  TARGET_PANE=$(tmux new-window -n "Oracle" -d -c "$WORKDIR" -P -F '#{pane_id}')
else
  TARGET_PANE=$(tmux split-window -t "Oracle" -d -c "$WORKDIR" -P -F '#{pane_id}')
  tmux select-layout -t "Oracle" tiled
fi

# Launch codex in the target pane
tmux send-keys -t "$TARGET_PANE" \
  "codex exec --full-auto -m ${MODEL} -c model_reasoning_effort=\"${REASONING}\" -o ${ORACLE_OUT} - < ${PROMPT_FILE}; echo DONE > ${ORACLE_DONE}" C-m

echo "ORACLE_ID=${ORACLE_ID}"
echo "ORACLE_OUT=${ORACLE_OUT}"
echo "ORACLE_DONE=${ORACLE_DONE}"
