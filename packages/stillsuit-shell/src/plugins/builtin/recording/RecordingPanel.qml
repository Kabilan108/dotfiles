import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import "../../../ui" as Ui
import "../meeting" as Meeting

Scope {
    id: root

    required property var context
    required property var screen
    required property string outputId
    readonly property var workflows: context.services.get("stillsuit.workflows")
    readonly property var recording: workflows ? workflows.recording : null
    readonly property var meeting: workflows ? workflows.meeting : null
    readonly property bool pulseRunning: recording && recording.phase === "recording"
        && !(context.settings && context.settings.values
            && context.settings.values.reducedMotion === true)
    readonly property real pulseScale: panelPulse.scale
    readonly property int meetingQueueRowCount: meetingQueue.rowCount
    readonly property var monitorRows: {
        var rows = context.compositor && Array.isArray(context.compositor.outputs)
            ? context.compositor.outputs : []
        if (rows.length > 0)
            return rows
        var focused = context.compositor ? String(context.compositor.focusedOutputId || "") : ""
        return focused ? [{ id: focused, name: focused }] : []
    }
    property bool opened: false
    property string selectedMonitor: ""
    property string draftTitle: ""
    property string renameTitle: ""
    property bool desktopAudio: true
    property bool microphone: false

    onPulseRunningChanged: if (!pulseRunning) panelPulse.scale = 1

    function open(payloadJson) {
        opened = true
        if (meeting)
            meeting.refresh()
        if (!recording || recording.phase === "idle" || recording.phase === "error")
            resetSetup()
        if (recording && recording.completed) {
            renameTitle = recording.title || recording.outputFilename.replace(/\.mp4$/, "")
            completionCountdown.start()
        }
    }

    function close() {
        opened = false
        completionCountdown.stop()
    }

    function resetSetup() {
        var focused = context.compositor ? String(context.compositor.focusedOutputId || "") : ""
        selectedMonitor = monitorRows.some(function(row) { return monitorName(row) === focused })
            ? focused : monitorRows.length > 0 ? monitorName(monitorRows[0]) : ""
        draftTitle = recording && typeof recording.defaultTitle === "function"
            ? recording.defaultTitle() : "Recording"
        desktopAudio = recording ? recording.defaultDesktopAudio : true
        microphone = recording ? recording.defaultMicrophone : false
    }

    function monitorName(row) {
        return String(row && (row.name || row.id) || "")
    }

    function monitorDescription(row) {
        if (!row)
            return "Display output"
        var makeModel = [String(row.make || ""), String(row.model || "")]
            .filter(function(value) { return value !== "" }).join(" ")
        var logical = row.logical || {}
        var modes = Array.isArray(row.modes) ? row.modes : []
        var mode = modes[Math.max(0, Number(row.current_mode || 0))] || {}
        var width = Number(mode.width || logical.width || 0)
        var height = Number(mode.height || logical.height || 0)
        var geometry = width > 0 && height > 0 ? width + "×" + height : ""
        return [makeModel, geometry].filter(function(value) { return value !== "" }).join(" · ")
            || "Display output"
    }

    function startCapture() {
        if (!recording)
            return "unavailable"
        return recording.start(recording.recordingDirectory, selectedMonitor,
            draftTitle.trim(), desktopAudio, microphone)
    }

    function closeSurface() {
        context.actions.surfaceClose("stillsuit.recording")
    }

    CompletionCountdown {
        id: completionCountdown
        timeoutMs: 5000
        interactionActive: completionHover.hovered || completionFocus.activeFocus
        onExpired: root.closeSurface()
    }

    Timer {
        interval: 100
        repeat: true
        running: completionCountdown.running
        onTriggered: completionCountdown.tick(interval)
    }

    Connections {
        target: root.recording
        function onPhaseChanged() {
            if (!root.recording)
                return
            if (root.opened && root.recording.completed) {
                root.renameTitle = root.recording.title
                completionCountdown.start()
            } else if (!root.recording.completed) {
                completionCountdown.stop()
            }
        }
        function onOutputPathChanged() {
            if (root.recording && root.recording.completed)
                root.renameTitle = root.recording.title
        }
    }

    PanelWindow {
        id: recordingWindow

        screen: root.screen
        visible: root.opened
        anchors { top: true; left: true; right: true; bottom: true }
        exclusiveZone: 0
        focusable: true
        color: "transparent"
        mask: Region {
            item: dismissArea
        }

        MouseArea {
            id: dismissArea
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                topMargin: root.context.theme.metrics.barHeight
            }
            acceptedButtons: Qt.AllButtons
            onClicked: root.closeSurface()
        }

        Ui.ShellSurface {
            id: card
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                topMargin: root.context.theme.metrics.barHeight
                    + root.context.theme.metrics.spaceUnit
            }
            width: root.recording && root.recording.active
                ? Math.max(activeContent.implicitWidth + 32, 480) : 480
            height: panelContent.implicitHeight + 32
            theme: root.context.theme
            kind: "panel"

            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) { mouse.accepted = true }
            }

            ColumnLayout {
                id: panelContent
                anchors { fill: parent; margins: 16 }
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    Ui.ShellIcon {
                        theme: root.context.theme
                        name: root.recording && root.recording.completed ? "success"
                            : root.recording && root.recording.phase === "error" ? "danger" : "record"
                        role: root.recording && root.recording.completed ? "success"
                            : root.recording && root.recording.phase === "error" ? "danger" : "recording"
                    }
                    Ui.ShellText {
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: root.recording && root.recording.completed ? "Recording saved"
                            : root.recording && root.recording.active ? "Screen recording" : "New recording"
                        sizeRole: "heading"
                    }
                    Ui.ShellButton {
                        theme: root.context.theme
                        label: ""
                        iconName: "close"
                        compact: true
                        ghost: true
                        accessibleName: "Close recording panel"
                        onClicked: root.closeSurface()
                    }
                }

                ColumnLayout {
                    visible: root.recording && root.recording.phase === "idle"
                    Layout.fillWidth: true
                    spacing: 12

                    Ui.ShellSectionLabel { theme: root.context.theme; text: "Capture output" }
                    Repeater {
                        model: root.monitorRows
                        Ui.ShellRow {
                            required property var modelData
                            Layout.fillWidth: true
                            theme: root.context.theme
                            label: root.monitorName(modelData)
                            description: root.monitorDescription(modelData)
                            iconName: "record"
                            trailingIconName: selected ? "check" : ""
                            selected: root.selectedMonitor === root.monitorName(modelData)
                            accessibleName: "Capture " + label
                            onClicked: root.selectedMonitor = root.monitorName(modelData)
                        }
                    }

                    Ui.ShellSectionLabel { theme: root.context.theme; text: "Recording title" }
                    Controls.TextField {
                        id: titleInput
                        Layout.fillWidth: true
                        implicitHeight: 38
                        text: root.draftTitle
                        placeholderText: "Recording title"
                        selectByMouse: true
                        color: root.context.theme.semantic.content.primary
                        placeholderTextColor: root.context.theme.semantic.content.muted
                        selectionColor: root.context.theme.semantic.accent.primary
                        selectedTextColor: root.context.theme.semantic.accent.onAccent
                        font.family: root.context.theme.typography.bodyFamily
                        font.pixelSize: root.context.theme.typography.baseSize
                        onTextEdited: root.draftTitle = text
                        background: Rectangle {
                            radius: root.context.theme.metrics.radiusSmall
                            color: root.context.theme.component.control.background
                            border.width: 1
                            border.color: root.context.theme.component.control.outline
                        }
                    }

                    Ui.ShellSectionLabel { theme: root.context.theme; text: "Audio" }
                    Ui.ShellToggle {
                        Layout.fillWidth: true
                        theme: root.context.theme
                        label: "Desktop audio"
                        description: "Capture the selected output stream"
                        checked: root.desktopAudio
                        onToggled: function(requestedChecked) { root.desktopAudio = requestedChecked }
                    }
                    Ui.ShellToggle {
                        Layout.fillWidth: true
                        theme: root.context.theme
                        label: "Microphone"
                        description: "Mix the default microphone into the recording"
                        checked: root.microphone
                        onToggled: function(requestedChecked) { root.microphone = requestedChecked }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Ui.ShellText {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            text: root.recording ? root.recording.recordingDirectory : ""
                            sizeRole: "caption"
                            role: "muted"
                            elide: Text.ElideMiddle
                        }
                        Ui.ShellButton {
                            theme: root.context.theme
                            label: "Start recording"
                            iconName: "record"
                            active: true
                            busy: root.recording && root.recording.actionRunning
                            enabled: root.recording && root.selectedMonitor !== "" && root.draftTitle.trim() !== ""
                            onClicked: root.startCapture()
                        }
                    }
                }

                RowLayout {
                    id: activeContent
                    visible: root.recording && root.recording.active
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    Rectangle {
                        id: panelPulse
                        implicitWidth: 10
                        implicitHeight: 10
                        radius: 5
                        color: root.recording && root.recording.paused
                            ? root.context.theme.semantic.status.warning
                            : root.context.theme.semantic.signal.recording
                        SequentialAnimation on scale {
                            running: root.pulseRunning
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.58; duration: 700; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutQuad }
                        }
                    }
                    Ui.ShellText {
                        theme: root.context.theme
                        text: root.recording ? root.recording.elapsedText : "00:00"
                        monospace: true
                        sizeRole: "heading"
                    }
                    Ui.ShellButton {
                        theme: root.context.theme
                        label: root.recording && root.recording.paused ? "Resume" : "Pause"
                        iconName: root.recording && root.recording.paused ? "play" : "pause"
                        compact: true
                        busy: root.recording && root.recording.actionRunning
                        onClicked: root.recording.togglePause()
                    }
                    Ui.ShellButton {
                        theme: root.context.theme
                        label: "Finish as meeting"
                        iconName: "success"
                        compact: true
                        active: true
                        busy: root.recording && root.recording.actionRunning
                        onClicked: root.recording.stopAsMeeting()
                    }
                    Ui.ShellButton {
                        theme: root.context.theme
                        label: "Finish"
                        compact: true
                        busy: root.recording && root.recording.actionRunning
                        onClicked: root.recording.finish()
                    }
                    Ui.ShellButton {
                        theme: root.context.theme
                        label: "Cancel"
                        iconName: "delete"
                        compact: true
                        destructive: true
                        busy: root.recording && root.recording.actionRunning
                        onClicked: root.recording.cancel()
                    }
                }

                FocusScope {
                    id: completionFocus
                    visible: root.recording && root.recording.completed
                    Layout.fillWidth: true
                    implicitHeight: completionContent.implicitHeight

                    HoverHandler { id: completionHover }

                    ColumnLayout {
                        id: completionContent
                        anchors { left: parent.left; right: parent.right }
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Ui.ShellText {
                                Layout.fillWidth: true
                                theme: root.context.theme
                                text: (root.recording ? root.recording.elapsedText : "00:00") + " · "
                                    + (root.recording ? root.recording.outputSizeText : "0 B")
                                role: "muted"
                            }
                            Ui.ShellStatus {
                                theme: root.context.theme
                                status: completionCountdown.interactionActive ? "warning" : "info"
                                label: completionCountdown.interactionActive ? "Close paused"
                                    : "Closes in " + completionCountdown.remainingSeconds + " s"
                            }
                        }

                        Ui.ShellSurface {
                            Layout.fillWidth: true
                            implicitHeight: 42
                            theme: root.context.theme
                            kind: "raised"
                            Ui.ShellText {
                                anchors { left: parent.left; right: copyPath.left; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 8 }
                                theme: root.context.theme
                                text: root.recording ? root.recording.outputPath : ""
                                monospace: true
                                sizeRole: "caption"
                                role: "secondary"
                                elide: Text.ElideMiddle
                            }
                            Ui.ShellButton {
                                id: copyPath
                                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                                theme: root.context.theme
                                label: root.recording && root.recording.copiedPath === root.recording.outputPath
                                    ? "Copied" : "Copy path"
                                iconName: "copy"
                                compact: true
                                onClicked: root.recording.copyOutputPath()
                            }
                        }

                        RowLayout {
                            visible: root.recording && root.recording.phase === "completed"
                            Layout.fillWidth: true
                            Controls.TextField {
                                id: renameInput
                                Layout.fillWidth: true
                                implicitHeight: 36
                                text: root.renameTitle
                                selectByMouse: true
                                color: root.context.theme.semantic.content.primary
                                selectionColor: root.context.theme.semantic.accent.primary
                                selectedTextColor: root.context.theme.semantic.accent.onAccent
                                font.family: root.context.theme.typography.bodyFamily
                                font.pixelSize: root.context.theme.typography.baseSize
                                onTextEdited: root.renameTitle = text
                                onAccepted: if (root.renameTitle.trim() !== "") root.recording.rename(root.renameTitle)
                                background: Rectangle {
                                    radius: root.context.theme.metrics.radiusSmall
                                    color: root.context.theme.component.control.background
                                    border.width: 1
                                    border.color: root.context.theme.component.control.outline
                                }
                            }
                            Ui.ShellButton {
                                theme: root.context.theme
                                label: "Rename"
                                iconName: "edit"
                                compact: true
                                busy: root.recording && root.recording.actionRunning
                                enabled: root.renameTitle.trim() !== ""
                                onClicked: root.recording.rename(root.renameTitle)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Ui.ShellButton {
                                theme: root.context.theme
                                label: "Open recording"
                                iconName: "play"
                                compact: true
                                busy: root.recording && root.recording.actionRunning
                                onClicked: root.recording.openRecording()
                            }
                            Ui.ShellButton {
                                theme: root.context.theme
                                label: "Open folder"
                                iconName: "folder"
                                compact: true
                                busy: root.recording && root.recording.actionRunning
                                onClicked: root.recording.openFolder()
                            }
                            Item { Layout.fillWidth: true }
                            Ui.ShellButton {
                                theme: root.context.theme
                                label: "Dismiss"
                                compact: true
                                busy: root.recording && root.recording.actionRunning
                                onClicked: {
                                    completionCountdown.stop()
                                    root.recording.dismiss()
                                    root.closeSurface()
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: !root.recording || root.recording.phase === "error"
                    Layout.fillWidth: true
                    spacing: 10
                    Ui.ShellText {
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: root.recording ? root.recording.errorMessage : "Recording workflow is unavailable."
                        role: "danger"
                        wrapMode: Text.Wrap
                    }
                    Ui.ShellButton {
                        Layout.alignment: Qt.AlignRight
                        theme: root.context.theme
                        label: "Dismiss"
                        onClicked: if (root.recording) root.recording.dismiss()
                    }
                }

                Meeting.MeetingQueueView {
                    id: meetingQueue
                    visible: rowCount > 0
                    Layout.fillWidth: true
                    context: root.context
                    meeting: root.meeting
                }
            }
        }
    }
}
