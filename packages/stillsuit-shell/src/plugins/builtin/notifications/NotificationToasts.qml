import QtQuick
import QtQuick.Layouts
import Quickshell

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
        focusable: false
        color: "transparent"
        implicitWidth: toastColumn.implicitWidth
        implicitHeight: toastColumn.implicitHeight

        ColumnLayout {
            id: toastColumn
            spacing: root.context.theme.metrics.spaceUnit * 2

            Repeater {
                model: root.service ? root.service.toastsForOutput(root.outputId) : []

                NotificationCard {
                    required property var modelData
                    context: root.context
                    service: root.service
                    snapshot: modelData
                }
            }
        }
    }
}
