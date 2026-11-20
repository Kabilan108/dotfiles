# Stillsuit fixture notes

## Isolation from the live session

- Run service-only fixtures with `QT_QPA_PLATFORM=offscreen`, and compositor fixtures against a private headless sway with `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR` pointing at it. A fixture that maps windows on the default platform attaches its overlays to the live compositor.
- Set `settings.watchFiles: false` in a fixture shell that loads services or plugins from the live checkout, as `d2-compositor/fixture-shell.qml` does. Quickshell hot-reloads on file changes, so an unrelated edit in the checkout resets the state under test. Fixtures that copy the source tree into a temp directory do not need it.
- Start headless sway with `DISPLAY` unset and `DBUS_SESSION_BUS_ADDRESS` pointing at a socket that does not exist. With no `DISPLAY` and a live bus address, D-Bus can autolaunch a session whose portals mount FUSE file systems inside the fixture's runtime directory.

## Waiting out Qt and Quickshell

- Retry an IPC call only on the exact reply `Not ready to accept queries yet.`, as `ipc` in `d2-compositor/run-fixtures.sh` does. `qs ipc` sometimes answers that without running the call, so the retry cannot repeat a side effect. Remove the loop once Quickshell stops sending that reply.
- Start a fixture's startup checks from `Component.onCompleted` through `Qt.callLater`. QML does not define the completion order between a root and its children, so a check run directly can see half-built children.
- Make a check on asynchronous state answer `pending` until the state is ready and poll it from the runner, as `runWidgetStability` in `fixtures/HostCoreRepairFixture.qml` does. Widget components load asynchronously and pure additions reach the bar on a later event-loop turn.
- Re-check a negative or count assertion after a settle delay, as `wait_for_constructions` in `bar-v2/run.sh` does with its 0.2 s sleep. Rebuilds scheduled with `Qt.callLater` can land after a check that already passed.
- Keep the `ticking` re-entry guard around `tick` in `launcher-qml/fixture-shell.qml`. Real key delivery spins the event loop, so the step timer can fire while a step is still acting.
- Do not assert the monitor name in recorder argv. `recording-meetings/run.sh` compares `lastStartArgs[0:3]` and `[4:]` and skips index 3 because the headless output's name varies by wlroots backend.

## Headless sway input and surfaces

- Do not write a fixture that needs pointer input on headless sway. The seat has no pointer, so `menu-host/fixture-shell.qml` calls the scrim's press handler directly at points inside and outside the content.
- Keep one idle `wtype -s 600000` running for the whole run when a fixture types keys, as `menu-host/run.sh` does. The seat starts without a keyboard, and a short-lived virtual keyboard per `wtype` call adds and removes the seat's keyboard capability around every keystroke.
- Keep the `menu-host-probe` toplevel floating at 600,300 in `menu-host/run.sh`. A compositor sends no frame callbacks to a surface it does not show, so a probe covering the output's top-left corner would hide the parked 1x1 menu surface and stall it in every case, not only the deliberate fullscreen stall that `checkStalledOpen` tests.

## Notifications

- Send a resident notification, or any notification whose sender must outlive an action, with `send_raw_notification` in `notifications/run-fixtures.sh`, which calls `org.freedesktop.Notifications.Notify` through `gdbus`. `notify-send` closes its own notification once an action arrives. The raw path can go if `notify-send` gains a way to stay open after an action.
