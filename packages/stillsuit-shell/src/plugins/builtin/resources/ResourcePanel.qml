import QtQuick
import QtQuick.Layouts
import Quickshell

Scope {
    id: root

    required property var context
    required property var screen
    required property string outputId
    required property var service
    readonly property var metrics: service
    property bool opened: false

    function open(payloadJson) { opened = true }
    function close() { opened = false }

    PanelWindow {
        screen: root.screen
        visible: root.opened
        anchors { top: true; left: true; right: true; bottom: true }
        exclusiveZone: 0
        focusable: true
        color: "transparent"

        MouseArea { anchors.fill: parent; onClicked: root.context.actions.surfaceClose("stillsuit.resources") }

        Rectangle {
            anchors { top: parent.top; right: parent.right; topMargin: root.context.theme.geometry.barHeight + root.context.theme.geometry.panelGap; rightMargin: root.context.theme.geometry.panelGap }
            width: 300
            height: content.implicitHeight + 28
            radius: root.context.theme.geometry.radius
            color: root.context.theme.colors.surface.panel
            border.width: 1
            border.color: root.context.theme.colors.border.normal

            MouseArea { anchors.fill: parent; onClicked: mouse => mouse.accepted = true }
            ColumnLayout {
                id: content
                anchors { fill: parent; margins: 14 }
                spacing: 10
                Text { text: "System resources"; color: root.context.theme.colors.text.primary; font.family: root.context.theme.typography.family; font.pixelSize: root.context.theme.typography.baseSize * 1.15; font.weight: root.context.theme.typography.weightBold }
                Repeater {
                    model: [
                        { label: "CPU", value: root.percent(root.metrics ? root.metrics.cpuPercent : null) },
                        { label: "Memory", value: root.percent(root.metrics ? root.metrics.memoryPercent : null) }
                    ]
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Text { text: modelData.label; color: root.context.theme.colors.text.secondary; font.family: root.context.theme.typography.family; font.pixelSize: root.context.theme.typography.baseSize }
                        Item { Layout.fillWidth: true }
                        Text { text: modelData.value; color: root.context.theme.colors.text.primary; font.family: root.context.theme.typography.monospaceFamily; font.pixelSize: root.context.theme.typography.baseSize }
                    }
                }
                Text { visible: !root.metrics; text: "Shared metrics service is not loaded."; color: root.context.theme.colors.text.tertiary; font.family: root.context.theme.typography.family; font.pixelSize: root.context.theme.typography.baseSize * 0.85 }
            }
        }
    }

    function percent(value) {
        if (value === undefined || value === null || value === "") return "--"
        var text = String(value)
        return text.indexOf("%") === -1 ? text + "%" : text
    }
}
