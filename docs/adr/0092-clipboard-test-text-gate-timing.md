# Clipboard tests set the text gate and read delays around fake wl-paste costs

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

The collector skips a text classification that takes longer than `STILLSUIT_CLIPBOARD_TEXT_GATE_SEC` (default 1.0 s). In tests every fake `wl-paste` call is a Python startup, and a classification makes several, so a multi-read offer can approach a tight gate on its own. The race tests need the opposite: reads stalled long enough that a benign offer A can answer metadata reads while a secret offer B answers payload reads (A, B, A, B). niri's focus query has a 0.3 s timeout.

## Decision

The Python tests default the gate to 2 s and the QML fixture exports 2 s. Stall tests set it to 250 ms and add read delays past it (0.15 s or 0.2 s per read). The slow-focus test delays niri's first answer by 0.2 s, below its 0.3 s timeout, with 0.03 s reads so the total passes the 250 ms gate.

## Consequences

The numbers depend on each other: the stall delay must exceed the gate, and the niri delay must stay under niri's timeout. Changing the collector's niri timeout or gate bounds means retuning these tests.

## Where

- `packages/stillsuit-shell/src/tests/clipboard/collector_test.py` (`text_gate`, `test_stalled_text_classification_is_skipped`, `test_slow_first_focus_answer_counts_toward_the_gate`)
- `packages/stillsuit-shell/src/tests/clipboard/run-qml-fixture.sh` (`STILLSUIT_CLIPBOARD_TEXT_GATE_SEC`)
