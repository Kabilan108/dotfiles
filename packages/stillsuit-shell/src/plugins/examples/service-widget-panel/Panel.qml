import QtQuick
import QtQuick.Layouts
import Stillsuit.Ui as Ui

Item {
    id: root
    readonly property bool hostedPanel: true
    implicitWidth: root.context.theme.metrics.panelWidth
    implicitHeight: content.implicitHeight + root.context.theme.metrics.panelPadding * 2
    visible: false

    required property var context
    required property var service
    required property var screen
    required property string outputId
    property bool opened: false

    function open(payloadJson) { opened = true }
    function close() { opened = false }

    Ui.ShellSurface {
        anchors.fill: parent
        theme: root.context.theme

        ColumnLayout {
            id: content
            anchors { fill: parent; margins: root.context.theme.metrics.panelPadding }
            spacing: root.context.theme.metrics.spaceUnit * 2

            Ui.ShellPanelHeader {
                Layout.fillWidth: true
                theme: root.context.theme
                title: "Counter"
                subtitle: root.service.ticks + " seconds since load"
            }

            Ui.ShellRow {
                Layout.fillWidth: true
                theme: root.context.theme
                iconName: "add"
                label: "Increment"
                trailingText: String(root.service.count)
                onClicked: root.service.increment()
            }

            RowLayout {
                spacing: root.context.theme.metrics.spaceUnit * 2
                Ui.ShellButton {
                    theme: root.context.theme
                    label: "Reset"
                    destructive: true
                    ghost: true
                    onClicked: root.service.reset()
                }
                Ui.ShellButton {
                    theme: root.context.theme
                    label: "Close"
                    ghost: true
                    onClicked: root.context.actions.surfaceClose("stillsuit.example-counter")
                }
            }
        }
    }
}
