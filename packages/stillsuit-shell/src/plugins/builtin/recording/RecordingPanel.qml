// Adapted from home/desktop/wayland/quickshell/stillsuit/RecordingPanel.qml
// for Lane D4. This view contains no Omarchy Quattro code.
import QtQuick
import QtQuick.Layouts
import Quickshell

Scope {
    id: root

    required property var context
    required property var screen
    required property string outputId
    readonly property var workflows: context.services.get("stillsuit.workflows")
    readonly property var recording: workflows ? workflows.recording : null
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

        MouseArea { anchors.fill: parent; onClicked: root.context.actions.surfaceClose("stillsuit.recording") }
        Rectangle {
            anchors { top: parent.top; left: parent.left; topMargin: root.context.theme.geometry.barHeight + root.context.theme.geometry.panelGap; leftMargin: root.context.theme.geometry.panelGap }
            width: 390
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
                Text { text: "Screen recording"; color: root.context.theme.colors.text.primary; font.family: root.context.theme.typography.family; font.pixelSize: root.context.theme.typography.baseSize * 1.15; font.weight: root.context.theme.typography.weightBold }
                Text { text: root.statusText(); color: root.context.theme.colors.text.secondary; font.family: root.context.theme.typography.family; font.pixelSize: root.context.theme.typography.baseSize }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: root.actionsForRecording()
                        Rectangle {
                            required property var modelData
                            implicitWidth: actionLabel.implicitWidth + 18
                            implicitHeight: actionLabel.implicitHeight + 10
                            radius: root.context.theme.geometry.radius * 0.65
                            color: root.context.theme.controls.normal.fill
                            border.width: 1
                            border.color: root.context.theme.controls.normal.border
                            Text { id: actionLabel; anchors.centerIn: parent; text: modelData.label; color: root.context.theme.controls.normal.text; font.family: root.context.theme.typography.family; font.pixelSize: root.context.theme.typography.baseSize * 0.85 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.invoke(modelData.method) }
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
                Text { visible: !root.recording; text: "Recording workflow is unavailable."; color: root.context.theme.colors.status.warning; font.family: root.context.theme.typography.family; font.pixelSize: root.context.theme.typography.baseSize * 0.85 }
            }
        }
    }

    function statusText() {
        if (!recording) return "No workflow service is loaded."
        if (recording.errorMessage) return recording.errorMessage
        if (recording.completed) return recording.outputFilename ? "Saved " + recording.outputFilename : "Recording saved"
        if (recording.active) return recording.paused ? "Paused at " + recording.elapsedText : "Recording " + recording.elapsedText
        return "Ready to record"
    }

    function actionsForRecording() {
        if (!recording) return []
        if (recording.active)
            return [
                { label: recording.paused ? "Resume" : "Pause", method: "togglePause" },
                { label: "Stop", method: "finish" }
            ]
        return [{ label: "Record", method: "start" }]
    }

    function invoke(method) {
        if (recording && typeof recording[method] === "function")
            recording[method]()
    }
}
