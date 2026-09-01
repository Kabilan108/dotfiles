import QtQuick
import QtQuick.Layouts
import "../../../ui" as Ui

Ui.ShellAction {
    id: root

    required property var context
    required property string outputId
    readonly property var workflows: context.services.get("stillsuit.workflows")
    readonly property var recording: workflows ? workflows.recording : null
    readonly property bool activeRecording: recording && recording.active === true
    readonly property bool paused: recording && recording.paused === true
    readonly property bool pulseRunning: activeRecording && !paused
        && !(context.settings && context.settings.values
            && context.settings.values.reducedMotion === true)
    readonly property real pulseScale: recordingPulse.scale
    readonly property color stateColor: paused
        ? context.theme.semantic.status.warning
        : context.theme.semantic.signal.recording

    onPulseRunningChanged: if (!pulseRunning) recordingPulse.scale = 1

    visible: activeRecording
    accessibleName: paused ? "Recording paused, " + recording.elapsedText
        : "Recording active, " + recording.elapsedText
    accessibleFallback: "Recording status"
    implicitWidth: indicatorRow.implicitWidth + 12
    implicitHeight: context.theme.metrics.barHeight
    onActivated: context.actions.surfaceToggle("stillsuit.recording", "")

    Rectangle {
        anchors.fill: parent
        radius: root.context.theme.metrics.radiusSmall
        color: root.pressed
            ? root.context.theme.semantic.surface.pressed
            : root.hovered ? root.context.theme.component.bar.clusterHover : "transparent"
        border.width: root.focusVisible ? 2 : 0
        border.color: root.context.theme.component.control.focus
    }

    RowLayout {
        id: indicatorRow
        anchors.centerIn: parent
        spacing: 6

        Item {
            implicitWidth: 12
            implicitHeight: 12
            Rectangle {
                id: recordingPulse
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: root.stateColor
                SequentialAnimation on scale {
                    running: root.pulseRunning
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.55; duration: 700; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutQuad }
                }
            }
            Ui.ShellIcon {
                visible: root.paused
                anchors.centerIn: parent
                theme: root.context.theme
                name: "pause"
                sizeRole: "small"
                color: root.stateColor
            }
        }

        Ui.ShellText {
            theme: root.context.theme
            text: root.recording ? root.recording.elapsedText : "REC"
            monospace: true
            sizeRole: "caption"
            color: root.stateColor
            font.weight: root.context.theme.typography.weightBold
        }
    }
}
