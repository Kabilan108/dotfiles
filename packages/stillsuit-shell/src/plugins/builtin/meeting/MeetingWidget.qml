// Ported from home/desktop/wayland/quickshell/stillsuit/MeetingIndicator.qml
// for Lane D4. This view contains no Omarchy Quattro code.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var context
    readonly property var workflows: context.services.get("stillsuit.workflows")
    readonly property var meeting: workflows ? workflows.meeting : null
    readonly property bool visibleState: meeting && meeting.visible !== false
    readonly property bool failed: meeting && meeting.failed === true
    readonly property bool completed: meeting && meeting.completed === true
    readonly property color stateColor: failed ? context.theme.colors.status.danger
        : completed ? context.theme.colors.status.success : context.theme.colors.status.info

    visible: visibleState
    implicitWidth: row.implicitWidth + 12
    implicitHeight: context.theme.geometry.barHeight
    radius: context.theme.geometry.radius
    color: pointer.containsMouse ? context.theme.controls.hover.fill : "transparent"

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text { text: root.failed ? "!" : root.completed ? "✓" : "✦"; color: root.stateColor; font.family: root.context.theme.typography.monospaceFamily; font.pixelSize: root.context.theme.typography.baseSize * 1.15 }
        Text { text: root.meeting && root.meeting.label ? root.meeting.label : root.completed ? "Minutes ready" : root.failed ? "Minutes failed" : "Making minutes"; color: root.stateColor; font.family: root.context.theme.typography.family; font.pixelSize: root.context.theme.typography.baseSize * 0.9; font.weight: root.context.theme.typography.weightMedium }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.togglePanel()
    }

    function togglePanel() {
        return context.actions.surfaceToggle("stillsuit.meeting", "")
    }
}
