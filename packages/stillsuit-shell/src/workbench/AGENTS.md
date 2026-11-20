# Stillsuit workbench notes

- Name the output `WB-1` in hand-written fixtures. `SyntheticCompositor.qml` builds outputs from the real Quickshell screens it was given and retargets `WB-1` to the first one; a fixture's `focusedOutputId` only selects among those screens, and any other output name gets no special handling.
- Write battery fixture percentages as human values above 1 (for example 15). `FixtureModels.qml` divides values above 1 by 100 because `BatteryService` expects UPower's 0 to 1 scale as Quickshell 0.3 reports it, so a fixture value of 1 means 100 percent, not 1 percent.
- Keep `SyntheticCompositor.qml` behaving like the niri adapter in `../services/NiriService.qml`: `focusWorkspace` updates the snapshot the way niri's `WorkspaceActivated` event would, and `lastFocusedWindowId` is null unless the named window exists.
