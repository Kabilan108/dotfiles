---
name: oracle
description: Consult OpenAI Codex (GPT-5.3) for a second opinion on hard problems. Use when stuck on a difficult bug, need to validate an architectural approach, want fresh eyes on a tricky implementation, or the user asks to "consult the oracle", "ask codex", or "get a second opinion". Launches Codex CLI non-interactively in a dedicated tmux Oracle window with xhigh reasoning.
---

# Oracle

Consult OpenAI Codex as a second-opinion oracle for hard problems. Runs `codex exec` non-interactively in a tmux "Oracle" window so the user can watch progress, with output captured for you to incorporate.

## Formulating the Query

Good oracle queries are specific and include enough context for independent reasoning:

- "Here's my approach to X. What edge cases or failure modes am I missing?" + relevant code
- "I'm choosing between A and B for X. Given these constraints, which is better?" + both approaches
- "This code has a bug — here are the symptoms and what I've ruled out." + code + errors
- "Review this implementation for correctness and performance." + code

**Prompt tips (Codex-specific):**
- Lead with the specific question, not background
- Include code excerpts inline, not entire files
- State constraints, language, framework
- Don't ask for a plan or preamble — ask for concrete analysis
- Request the format you want back: "list the issues", "compare tradeoffs", "find the bug"

## Launching the Oracle

### 1. Write the prompt

```bash
ORACLE_ID="oracle-$(date +%s)"
cat > /tmp/${ORACLE_ID}-prompt.txt << 'ORACLE_PROMPT'
[Your specific question]

[Relevant code, errors, context]

Respond with concrete analysis. No preamble.
ORACLE_PROMPT
```

### 2. Run the oracle script

This skill bundles `scripts/oracle-run.sh` which handles tmux window management, codex invocation, and output capture. Locate it relative to this skill's directory and run it:

```bash
eval "$(bash agents/skills/oracle/scripts/oracle-run.sh /tmp/${ORACLE_ID}-prompt.txt)"
```

This sets `ORACLE_ID`, `ORACLE_OUT`, and `ORACLE_DONE` variables. The script:
- Creates an "Oracle" tmux window if one doesn't exist
- Adds a new pane in the Oracle window if one already exists (concurrent queries tile together)
- Runs `codex exec --full-auto -m gpt-5.3-codex -c model_reasoning_effort="xhigh" -o <output> - < <prompt>`
- Writes a sentinel file when codex finishes

**Defaults:** model `gpt-5.3-codex`, reasoning `xhigh`. Override with positional args:

```bash
eval "$(bash agents/skills/oracle/scripts/oracle-run.sh /tmp/${ORACLE_ID}-prompt.txt gpt-5-codex high)"
```

### 3. Wait for results

**If blocked** (you need the answer before continuing):

Run a background Bash command that polls for the sentinel, then read the output when it completes:

```bash
# run_in_background: true
while [ ! -f "${ORACLE_DONE}" ]; do sleep 10; done
cat "${ORACLE_OUT}"
```

**If not blocked** (you have other work to do):

Spin up the same background poll, then continue with your current task. Check the result when the background task finishes or when you need the answer.

## Incorporating Results

After reading the oracle output:

- Synthesize the findings — don't dump the raw response
- Note where the oracle agrees or disagrees with your analysis
- If it found issues, address them
- If it suggests a different approach, present both to the user with tradeoffs
- Tell the user you consulted the oracle and what it found

## Cleanup

```bash
rm -f /tmp/${ORACLE_ID}-{prompt,output,done}.txt
```

## Tuning

| Parameter | Default | Override |
|-----------|---------|---------|
| Model | `gpt-5.3-codex` | 2nd arg to `oracle-run.sh` |
| Reasoning effort | `xhigh` | 3rd arg to `oracle-run.sh` |
| Working directory | `$PWD` | `cd` before running the script |

Use `xhigh` for the hardest problems (architecture, subtle bugs). Use `high` for faster turnaround on moderate questions.
