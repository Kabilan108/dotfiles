# Panel and menu hosts own geometry, input masks and teardown order

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

`PanelHost` covers the whole output and positions panels in output coordinates, which already include the bar's reserved height. Hosts cache plugin content items that outlive any one host window. Bar slots register anchor resolvers with `SurfaceRouter.barAnchorFacade`, and a replacement slot can register before the old slot finishes destruction.

## Decision

- `PanelHost` sets `exclusionMode: ExclusionMode.Ignore`, so the bar's exclusive zone is not counted twice.
- `PanelHost`'s input mask is the dismiss area below the bar, so a single click on another bar entry reaches it while a panel is open.
- On destruction, `PanelHost` and `MenuHost` set their current content's parent to null before unregistering, keeping cached plugin objects out of the dying window's visual tree.
- `barAnchorFacade.clear` removes a resolver only when the caller passes the resolver currently stored, so an old slot cannot remove its replacement.

## Consequences

Panel geometry code must keep using output coordinates. Any new host that caches plugin items needs the same reparent-on-destruction step.

## Where

- `packages/stillsuit-shell/src/core/PanelHost.qml` (`exclusionMode`, `mask`, `Component.onDestruction`)
- `packages/stillsuit-shell/src/core/MenuHost.qml` (`Component.onDestruction`)
- `packages/stillsuit-shell/src/core/SurfaceRouter.qml` (`barAnchorFacade.clear`)
