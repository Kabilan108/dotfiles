// Ported from home/desktop/wayland/quickshell/stillsuit/RecordingIndicator.qml
// for Lane D4. This view contains no Omarchy Quattro code.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var context
    required property string outputId
    readonly property var workflows: context.services.get("stillsuit.workflows")
    readonly property var recording: workflows ? workflows.recording : null
    readonly property bool active: recording && recording.active === true
    readonly property bool paused: recording && recording.paused === true
    readonly property color stateColor: paused ? context.theme.colors.status.warning : context.theme.colors.status.danger

    visible: active
    implicitWidth: row.implicitWidth + 12
    implicitHeight: context.theme.geometry.barHeight
    radius: context.theme.geometry.radius
    color: pointer.containsMouse ? context.theme.controls.hover.fill : "transparent"

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Item {
            implicitWidth: 10
            implicitHeight: 10
            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: root.stateColor
                SequentialAnimation on scale {
                    running: root.active && !root.paused
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.55; duration: 700 }
                    NumberAnimation { to: 1; duration: 700 }
                }
            }
        }
        Text { text: root.recording && root.recording.elapsedText ? root.recording.elapsedText : "REC"; color: root.stateColor; font.family: root.context.theme.typography.monospaceFamily; font.pixelSize: root.context.theme.typography.baseSize; font.weight: root.context.theme.typography.weightBold }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.togglePanel()
    }

    function togglePanel() {
        return context.actions.surfaceToggle("stillsuit.recording", "")
    }
}
