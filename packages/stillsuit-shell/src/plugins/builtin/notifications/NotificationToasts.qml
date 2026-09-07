import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    required property var context
    required property var screen
    required property var service

    property string outputId: String(screen.name || "")

    PanelWindow {
        screen: root.screen
        visible: root.service && root.service.toastsForOutput(root.outputId).length > 0
        anchors {
            top: true
            right: true
        }
        margins {
            top: root.context.theme.metrics.barHeight + root.context.theme.metrics.spaceUnit * 2
            right: root.context.theme.metrics.spaceUnit * 2
        }
        exclusiveZone: 0
        aboveWindows: true
        focusable: false
        color: "transparent"
        implicitWidth: toastColumn.implicitWidth
        height: Math.max(1, root.screen.height
            - root.context.theme.metrics.barHeight
            - root.context.theme.metrics.spaceUnit * 4)
        mask: Region { item: toastColumn }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "stillsuit.notifications"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        ColumnLayout {
            id: toastColumn
            anchors {
                top: parent.top
                right: parent.right
            }
            spacing: root.context.theme.metrics.spaceUnit * 2

            Repeater {
                model: root.service ? root.service.toastDecksForOutput(root.outputId) : []

                NotificationDeck {
                    required property var modelData
                    context: root.context
                    service: root.service
                    deck: modelData
                }
            }
        }

    }
}
