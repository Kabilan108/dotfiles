import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services
import "notifications" as Notifications

ShellRoot {
    id: fixture

    property int toastViewCount: 0
    property int centerViewCount: 0

    QtObject {
        id: serviceFacade
        function get(pluginId) {
            return pluginId === "stillsuit.notifications" ? notificationService : null
        }
    }

    QtObject {
        id: fixtureContext
        property var settings: ({
            values: { claimNotificationBus: true },
            paths: { stateRoot: Quickshell.env("XDG_STATE_HOME") }
        })
        property var compositor: ({
            focusedOutputId: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "",
            outputs: Quickshell.screens.map(function(screen) { return { id: screen.name } })
        })
        property var logger: ({
            warn: function(message) { console.warn(message) }
        })
        property var services: serviceFacade
        property var theme: ({
            colors: {
                surface: { canvas: "#11111b", panel: "#181825", raised: "#313244", hover: "#45475a" },
                text: { primary: "#cdd6f4", secondary: "#bac2de", tertiary: "#a6adc8", onAccent: "#11111b" },
                border: { subtle: "#313244", normal: "#45475a", focus: "#89b4fa" },
                status: { info: "#89b4fa", success: "#a6e3a1", warning: "#f9e2af", danger: "#f38ba8" }
            },
            controls: {
                normal: { fill: "#313244", text: "#cdd6f4", border: "#45475a" },
                hover: { fill: "#45475a", text: "#cdd6f4", border: "#585b70" },
                active: { fill: "#585b70", text: "#cdd6f4", border: "#89b4fa" }
            },
            typography: { family: "sans-serif", monospaceFamily: "monospace", baseSize: 13 },
            geometry: { radius: 8, barHeight: 30, panelGap: 8 }
        })
    }

    Services.NotificationService {
        id: notificationService
        context: fixtureContext
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Notifications.NotificationToasts {
                required property var modelData
                context: fixtureContext
                screen: modelData
                Component.onCompleted: fixture.toastViewCount += 1
                Component.onDestruction: fixture.toastViewCount -= 1
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Notifications.NotificationCenter {
                required property var modelData
                context: fixtureContext
                screen: modelData
                Component.onCompleted: fixture.centerViewCount += 1
                Component.onDestruction: fixture.centerViewCount -= 1
            }
        }
    }

    IpcHandler {
        target: "stillsuit-notification-view-fixture"
        function ready(): string {
            var screenCount = Quickshell.screens.length
            return notificationService.ready && notificationService.serverActive
                && fixture.toastViewCount === screenCount
                && fixture.centerViewCount === screenCount ? "ready" : "loading"
        }
        function topology(): string {
            return JSON.stringify({
                serviceInstances: 1,
                outputs: Quickshell.screens.length,
                toastViews: fixture.toastViewCount,
                centerViews: fixture.centerViewCount
            })
        }
    }
}
