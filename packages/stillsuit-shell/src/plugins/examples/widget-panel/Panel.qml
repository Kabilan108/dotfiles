import QtQuick
import QtQuick.Layouts
import Stillsuit.Ui as Ui

// A hosted panel is plain Item content. The core owns the window, placement
// below the bar, outside-click and Escape dismissal, and output switching.
Item {
    id: root
    readonly property bool hostedPanel: true
    implicitWidth: root.context.theme.metrics.panelWidth
    implicitHeight: content.implicitHeight + root.context.theme.metrics.panelPadding * 2
    visible: false

    required property var context
    required property var screen
    required property string outputId
    property bool opened: false
    property int clicks: 0

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
                title: "Example"
                subtitle: "Hosted on " + root.outputId
            }

            Ui.ShellRow {
                Layout.fillWidth: true
                theme: root.context.theme
                iconName: "check"
                label: "Clicks"
                trailingText: String(root.clicks)
                onClicked: root.clicks += 1
            }

            Ui.ShellButton {
                theme: root.context.theme
                label: "Close"
                ghost: true
                onClicked: root.context.actions.surfaceClose("stillsuit.example-panel")
            }
        }
    }
}
