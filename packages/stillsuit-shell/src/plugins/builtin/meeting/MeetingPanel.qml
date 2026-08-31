// Adapted from the current Stillsuit meeting workflow presentation for Lane D4.
// This view contains no Omarchy Quattro code.
import QtQuick
import QtQuick.Layouts
import Quickshell

Scope {
    id: root

    required property var context
    required property var screen
    required property string outputId
    readonly property var workflows: context.services.get("stillsuit.workflows")
    readonly property var meeting: workflows ? workflows.meeting : null
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

        MouseArea { anchors.fill: parent; onClicked: root.context.actions.surfaceClose("stillsuit.meeting") }
        Rectangle {
            anchors { top: parent.top; left: parent.left; topMargin: root.context.theme.geometry.barHeight + root.context.theme.geometry.panelGap; leftMargin: root.context.theme.geometry.panelGap }
            width: 360
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
                Text { text: "Meeting minutes"; color: root.context.theme.colors.text.primary; font.family: root.context.theme.typography.family; font.pixelSize: root.context.theme.typography.baseSize * 1.15; font.weight: root.context.theme.typography.weightBold }
                Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: root.statusText(); color: root.context.theme.colors.text.secondary; font.family: root.context.theme.typography.family; font.pixelSize: root.context.theme.typography.baseSize }
                Rectangle {
                    visible: root.meeting && root.meeting.completed === true && typeof root.meeting.openResult === "function"
                    Layout.alignment: Qt.AlignRight
                    implicitWidth: resultLabel.implicitWidth + 18
                    implicitHeight: resultLabel.implicitHeight + 10
                    radius: root.context.theme.geometry.radius * 0.65
                    color: root.context.theme.controls.normal.fill
                    border.width: 1
                    border.color: root.context.theme.controls.normal.border
                    Text { id: resultLabel; anchors.centerIn: parent; text: "Open result"; color: root.context.theme.controls.normal.text; font.family: root.context.theme.typography.family; font.pixelSize: root.context.theme.typography.baseSize * 0.85 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.meeting.openResult() }
                }
            }
        }
    }

    function statusText() {
        if (!meeting) return "Meeting workflow is unavailable."
        if (meeting.failed) return meeting.errorMessage || meeting.label || "Minutes generation failed."
        if (meeting.completed) return meeting.label || "Minutes are ready."
        return meeting.label || "Minutes are being prepared."
    }
}
