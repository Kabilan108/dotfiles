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
    readonly property string indicatorIconName: paused ? "pause" : "record"
    readonly property string outputLabel: recording ? String(recording.monitor || "") : ""
    readonly property color stateColor: paused
        ? context.theme.semantic.status.warning
        : context.theme.semantic.signal.recording

    visible: activeRecording
    accessibleName: (paused ? "Recording paused, " : "Recording active, ")
        + recording.elapsedText + (outputLabel ? ", " + outputLabel : "")
    accessibleFallback: "Recording status"
    implicitWidth: indicatorRow.implicitWidth + 14
    implicitHeight: Math.max(22, context.theme.metrics.barHeight - 6)
    onActivated: root.toggleRecording()

    function toggleRecording() {
        if (recording)
            recording.togglePause()
    }

    function openPanel() {
        context.actions.surfaceToggle("stillsuit.recording", JSON.stringify({outputId: root.outputId}))
    }

    function queueSingleClick() {
        singleClickTimer.restart()
    }

    function handleDoubleClick() {
        singleClickTimer.stop()
        openPanel()
    }

    Timer {
        id: singleClickTimer
        interval: 300
        onTriggered: root.toggleRecording()
    }

    Rectangle {
        anchors.fill: parent
        radius: root.context.theme.metrics.radiusSmall
        color: clickArea.pressed
            ? root.context.theme.semantic.surface.pressed
            : clickArea.containsMouse ? root.context.theme.component.bar.clusterHover : "transparent"
        border.width: 0
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        enabled: root.canActivate
        hoverEnabled: true
        cursorShape: root.canActivate ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: root.forceActiveFocus(Qt.MouseFocusReason)
        onClicked: root.queueSingleClick()
        onDoubleClicked: function (mouse) {
            mouse.accepted = true
            root.handleDoubleClick()
        }
    }

    RowLayout {
        id: indicatorRow
        anchors.centerIn: parent
        spacing: 6

        Ui.ShellIcon {
            theme: root.context.theme
            name: root.indicatorIconName
            pixelSize: Math.max(1, root.context.theme.metrics.iconSmall
                - root.context.theme.metrics.spaceUnit / 2)
            color: root.stateColor
        }

        Ui.ShellText {
            theme: root.context.theme
            text: root.recording ? root.recording.elapsedText : "REC"
            monospace: true
            sizeRole: "caption"
            color: root.stateColor
            font.weight: root.context.theme.typography.weightBold
        }

        Ui.ShellText {
            id: outputName
            visible: root.outputLabel !== ""
            Layout.preferredWidth: Math.min(implicitWidth,
                root.context.theme.metrics.spaceUnit * 40)
            theme: root.context.theme
            text: root.outputLabel
            sizeRole: "caption"
            role: "muted"
            elide: Text.ElideRight
        }
    }
}
