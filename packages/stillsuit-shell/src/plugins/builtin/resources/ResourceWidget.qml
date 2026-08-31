import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var context
    property var service: null
    readonly property var metrics: service

    implicitWidth: row.implicitWidth + 14
    implicitHeight: context.theme.geometry.barHeight
    radius: context.theme.geometry.radius
    color: pointer.containsMouse ? context.theme.controls.hover.fill : "transparent"

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Text {
            text: "MEM " + root.percent(root.metrics ? root.metrics.memoryPercent : null)
            color: root.context.theme.colors.text.secondary
            font.family: root.context.theme.typography.monospaceFamily
            font.pixelSize: root.context.theme.typography.baseSize * 0.86
        }
        Text {
            text: "CPU " + root.percent(root.metrics ? root.metrics.cpuPercent : null)
            color: root.context.theme.colors.text.secondary
            font.family: root.context.theme.typography.monospaceFamily
            font.pixelSize: root.context.theme.typography.baseSize * 0.86
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.togglePanel()
    }

    function percent(value) {
        if (value === undefined || value === null || value === "")
            return "--"
        var text = String(value)
        return text.indexOf("%") === -1 ? text + "%" : text
    }

    function togglePanel() {
        return context.actions.surfaceToggle("stillsuit.resources", "")
    }
}
