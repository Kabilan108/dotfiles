# Tray plugin notes

- Do not run another tray host beside the shell, and keep the SystemTray import in `Service.qml`. Importing it registers the shell as the session's StatusNotifierWatcher and Host; Electron and Qt apps create a tray icon only when a watcher is on the session bus.
- Keep one live QsMenuOpener per submenu level in `Panel.qml`. A child entry is owned by its parent opener's model, so reusing one opener destroys the entry being shown.
- Keep identity comparison on the ScriptModel in `Widget.qml`. Live items are unique SystemTrayItem objects, but their app-chosen id strings are not guaranteed unique, and identity is what lets each icon keep its delegate and decoded image when the filtered list is rebuilt.
