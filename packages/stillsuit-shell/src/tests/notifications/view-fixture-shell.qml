import QtQuick
import Quickshell
import Quickshell.Io
import "src/services" as Services
import "src/plugins/builtin/notifications" as Notifications

ShellRoot {
    id: fixture

    property int toastViewCount: 0
    property int centerViewCount: 0
    property int widgetViewCount: 0
    property var fixtureTheme: ({})
    property bool themeReady: false

    FileView {
        path: Quickshell.env("STILLSUIT_NOTIFICATION_VIEW_THEME")
        printErrors: true
        onLoaded: {
            fixture.fixtureTheme = JSON.parse(text())
            fixture.themeReady = true
        }
    }

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
        property var actions: ({
            surfaceToggle: function(pluginId, payloadJson) { return "ok" }
        })
        property var theme: fixture.fixtureTheme
    }

    Services.NotificationService {
        id: notificationService
        context: fixtureContext
    }

    Variants {
        model: fixture.themeReady ? Quickshell.screens : []
        delegate: Component {
            Notifications.NotificationToasts {
                required property var modelData
                context: fixtureContext
                service: notificationService
                screen: modelData
                Component.onCompleted: fixture.toastViewCount += 1
                Component.onDestruction: fixture.toastViewCount -= 1
            }
        }
    }

    Variants {
        model: fixture.themeReady ? Quickshell.screens : []
        delegate: Component {
            Notifications.NotificationCenter {
                required property var modelData
                context: fixtureContext
                service: notificationService
                screen: modelData
                Component.onCompleted: fixture.centerViewCount += 1
                Component.onDestruction: fixture.centerViewCount -= 1
            }
        }
    }

    Variants {
        model: fixture.themeReady ? Quickshell.screens : []
        delegate: Component {
            Notifications.Widget {
                required property var modelData
                context: fixtureContext
                service: notificationService
                outputId: modelData.name
                Component.onCompleted: fixture.widgetViewCount += 1
                Component.onDestruction: fixture.widgetViewCount -= 1
            }
        }
    }

    IpcHandler {
        target: "stillsuit-notification-view-fixture"
        function ready(): string {
            var screenCount = Quickshell.screens.length
            return fixture.themeReady && notificationService.ready && notificationService.serverActive
                && fixture.toastViewCount === screenCount
                && fixture.centerViewCount === screenCount
                && fixture.widgetViewCount === screenCount ? "ready" : "loading"
        }
        function topology(): string {
            return JSON.stringify({
                serviceInstances: 1,
                outputs: Quickshell.screens.length,
                toastViews: fixture.toastViewCount,
                centerViews: fixture.centerViewCount,
                widgetViews: fixture.widgetViewCount
            })
        }
    }
}
