import QtQuick
import QtQuick.Layouts
import "../../../ui" as Ui

Ui.ShellAction {
    id: root

    required property var context
    required property string outputId
    property var service: null
    readonly property alias indicatorDot: recordingDot
    readonly property bool showsRecordingDot: activeRecording && !paused
    readonly property var workflows: context.services.get("stillsuit.workflows")
    readonly property var recording: workflows ? workflows.recording : null
    readonly property var meeting: workflows ? workflows.meeting : null
    readonly property bool activeRecording: recording && recording.active === true
    readonly property bool activeMeeting: meeting && meeting.active === true
    readonly property bool completedMeeting: meeting
        && meeting.completionVisible === true
    readonly property bool failedMeeting: meeting
        && meeting.failureVisible === true
    readonly property bool paused: recording && recording.paused === true
    readonly property bool microphoneCaptured: !!service && service.microphoneCaptured === true
    readonly property bool microphoneLive: !!service && service.microphoneLive === true
    readonly property real microphoneLevel: service ? Number(service.level) || 0 : 0
    readonly property bool reducedMotion: context.settings
        && context.settings.values
        && context.settings.values.reducedMotion === true
    readonly property string microphoneDescription: !microphoneCaptured
        ? "microphone off"
        : microphoneLive ? "microphone live" : "microphone muted"
    readonly property string indicatorIconName: activeRecording
        ? paused ? "pause" : "record"
        : "agent"
    readonly property string outputLabel: {
        if (!recording)
            return ""
        var rect = recording.rect
        if (String(recording.target || "monitor") !== "monitor" && rect && Number(rect.w) > 0 && Number(rect.h) > 0)
            return "REC " + String(rect.output || recording.monitor || "") + " " + Number(rect.w) + "×" + Number(rect.h)
        return String(recording.monitor || "")
    }
    readonly property string meetingLabel: {
        if (!activeMeeting)
            return ""
        var suppliedLabel = String(meeting.label || "").trim()
        if (suppliedLabel !== "")
            return suppliedLabel
        var labels = {
            staging: "Preparing meeting",
            queued: "Meeting queued",
            preparing: "Preparing audio",
            chunking: "Splitting audio",
            transcribing: "Transcribing meeting",
            diarizing: "Identifying speakers",
            aligning: "Aligning transcript",
            generating: "Writing minutes",
            enriching: "Adding meeting context",
            writing: "Saving meeting notes"
        }
        return labels[String(meeting.phase || "")] || "Preparing meeting minutes"
    }
    readonly property color iconColor: failedMeeting && !activeRecording
        ? context.theme.semantic.status.danger
        : completedMeeting && !activeRecording
        ? context.theme.semantic.status.success
        : activeMeeting && !activeRecording
            ? context.theme.semantic.status.info
            : paused
                ? context.theme.semantic.status.warning
                : context.theme.semantic.signal.recording
    readonly property color textColor: failedMeeting && !activeRecording
        ? context.theme.semantic.status.danger
        : (activeMeeting || completedMeeting) && !activeRecording
        ? context.theme.semantic.content.secondary
        : paused
            ? context.theme.semantic.status.warning
            : context.theme.semantic.signal.recording

    visible: activeRecording || activeMeeting || completedMeeting || failedMeeting
    accessibleName: activeRecording
        ? (paused ? "Recording paused, " : "Recording active, ")
            + recording.elapsedText + ", " + microphoneDescription
            + (outputLabel ? ", " + outputLabel : "")
        : failedMeeting
            ? "Meeting processing failed. Click for details."
            : completedMeeting ? "Meeting note ready. Click to copy its path." : meetingLabel
    accessibleFallback: "Recording status"
    implicitWidth: indicatorRow.implicitWidth + 18
    implicitHeight: Math.max(22, context.theme.metrics.barHeight - 6)
    onActivated: root.toggleRecording()

    function toggleRecording() {
        if (activeRecording && recording)
            recording.togglePause()
        else if (completedMeeting && meeting)
            meeting.copyNotePath()
        else if (activeMeeting || failedMeeting)
            openPanel()
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
        anchors {
            fill: parent
            leftMargin: root.context.theme.metrics.spaceUnit
        }
        radius: root.context.theme.metrics.radiusSmall
        color: clickArea.pressed
            ? root.context.theme.semantic.surface.pressed
            : clickArea.containsMouse ? root.context.theme.component.bar.clusterHover : "transparent"
        border.width: 0
    }

    MouseArea {
        id: clickArea
        anchors {
            fill: parent
            leftMargin: root.context.theme.metrics.spaceUnit
        }
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
        anchors.horizontalCenterOffset: 2
        spacing: 6

        Item {
            id: recordingDot
            visible: root.showsRecordingDot
            readonly property real disc: 2 * Math.max(1, Math.floor((root.context.theme.metrics.iconSmall
                - root.context.theme.metrics.spaceUnit / 2) / 2))
            readonly property real hole: disc / 2
            readonly property real haloMin: 1
            readonly property real haloMax: Math.round(root.context.theme.metrics.spaceUnit * 1.25)
            readonly property real halo: root.microphoneLive
                ? haloMin + root.microphoneLevel * (haloMax - haloMin)
                : 0
            readonly property real box: disc + haloMax * 2
            Layout.preferredWidth: box
            Layout.preferredHeight: box

            // A fixed-size circle scaled about its centre grows evenly on
            // every side; resizing it would snap its position to whole pixels.
            Rectangle {
                width: recordingDot.box
                height: width
                radius: width / 2
                scale: (recordingDot.disc + recordingDot.halo * 2) / recordingDot.box
                color: root.iconColor
                opacity: root.microphoneLive ? 0.42 : 0
                antialiasing: true

                Behavior on opacity {
                    NumberAnimation { duration: root.reducedMotion ? 0 : root.context.theme.motion.fast }
                }
            }

            Rectangle {
                x: (recordingDot.box - width) / 2
                y: x
                width: recordingDot.disc
                height: width
                radius: width / 2
                color: "transparent"
                border.width: (recordingDot.disc - recordingDot.hole) / 2
                border.color: root.iconColor
                antialiasing: true
            }
        }

        Ui.ShellIcon {
            visible: !root.showsRecordingDot
            theme: root.context.theme
            name: root.indicatorIconName
            pixelSize: Math.max(1, root.context.theme.metrics.iconSmall
                - root.context.theme.metrics.spaceUnit / 2)
            color: root.iconColor
        }

        Ui.ShellText {
            theme: root.context.theme
            text: root.activeRecording
                ? root.recording.elapsedText
                : root.failedMeeting
                    ? "Meeting failed"
                    : root.completedMeeting ? "Meeting note ready" : root.meetingLabel
            monospace: root.activeRecording
            sizeRole: "caption"
            color: root.textColor
            font.weight: root.context.theme.typography.weightBold
        }

        Ui.ShellText {
            id: outputName
            visible: root.activeRecording && root.outputLabel !== ""
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
