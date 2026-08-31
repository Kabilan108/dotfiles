import QtQuick
import QtQuick.Layouts
import Quickshell

Scope {
    id: root

    required property var context
    required property var screen

    property var service: context.services.get("stillsuit.notifications")
    property string outputId: String(screen.name || "")

    PanelWindow {
        screen: root.screen
        visible: root.service && root.service.toastsForOutput(root.outputId).length > 0
        anchors {
            top: true
            right: true
        }
        margins {
            top: root.context.theme.geometry.panelGap
            right: root.context.theme.geometry.panelGap
        }
        exclusiveZone: 0
        focusable: false
        color: "transparent"
        implicitWidth: toastColumn.implicitWidth
        implicitHeight: toastColumn.implicitHeight

        ColumnLayout {
            id: toastColumn
            spacing: root.context.theme.geometry.panelGap

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
