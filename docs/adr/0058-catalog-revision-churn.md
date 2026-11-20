# Catalog and registry suppress redundant revisions and refreshes

Status: Accepted. Recorded from code comments on 2026-11-20.

## Context

Every service and surface revision walks the catalog's topological order. Containment sweeps unload every affected plugin id, most of which never loaded. Registry and router revisions arrive in bursts. `Qt.callLater` collapses repeated calls only when they pass the same function object.

## Decision

- `PluginCatalog.topologicalOrder` caches its result keyed on the identity of `internalEntries`, which is replaced wholesale on install, and returns a copy because some callers reverse it in place.
- `ServiceRegistry._setState` skips the revision bump when it would mark an id `unloaded` that has no state.
- `IpcFacade._queueSettledProfileRefresh` always passes the same function, `root._refreshSettledProfileState`, to `Qt.callLater`, so a burst schedules one refresh.

## Consequences

Mutating `internalEntries` in place would serve a stale order; it must keep being replaced. Wrapping the callLater target in a fresh closure would schedule one refresh per call.

## Where

- `packages/stillsuit-shell/src/core/PluginCatalog.qml` (`topologicalOrder`)
- `packages/stillsuit-shell/src/core/ServiceRegistry.qml` (`_setState`)
- `packages/stillsuit-shell/src/core/IpcFacade.qml` (`_queueSettledProfileRefresh`)
