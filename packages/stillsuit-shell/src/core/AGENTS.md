# Stillsuit core notes

- Replace `internalEntries` in `PluginCatalog.qml` wholesale; never mutate it in place. `topologicalOrder` caches its result on the identity of that object, because every service and surface revision walks the order, so an in-place edit serves a stale order.
- Pass `Qt.callLater` the same function object on every call, as `_queueSettledProfileRefresh` in `IpcFacade.qml` does with `root._refreshSettledProfileState`. `Qt.callLater` collapses repeated calls only for an identical function, so a fresh closure schedules one refresh per registry or router revision in a burst.
- A host that caches plugin content must set that content's `parent` to null in `Component.onDestruction` before it unregisters, as `PanelHost.qml` and `MenuHost.qml` do. Cached plugin items outlive any one host window and must not stay in a dying window's visual tree.
