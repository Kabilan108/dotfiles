import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import "../../../ui" as Ui

Item {
    id: root
    readonly property bool hostedPanel: true
    implicitWidth: root.recording && root.recording.active
        ? activeContent.implicitWidth + root.context.theme.metrics.panelPadding * 2
        : root.recording && root.recording.completed
            ? Math.max(root.context.theme.metrics.panelWidth,
                footerActions.implicitWidth + root.context.theme.metrics.panelPadding * 2)
            : root.context.theme.metrics.panelWidth
    implicitHeight: panelContent.implicitHeight + root.context.theme.metrics.panelPadding * 2
    visible: false

    required property var context
    required property var screen
    required property string outputId
    readonly property var workflows: context.services.get("stillsuit.workflows")
    readonly property var recording: workflows ? workflows.recording : null
    readonly property var meeting: workflows ? workflows.meeting : null
    readonly property int meetingQueueRowCount: meetingQueue.rowCount
    readonly property var monitorRows: {
        var rows = context.compositor && Array.isArray(context.compositor.outputs) ? context.compositor.outputs : [];
        if (rows.length > 0)
            return rows;
        var focused = context.compositor ? String(context.compositor.focusedOutputId || "") : "";
        return focused ? [
            {
                id: focused,
                name: focused
            }
        ] : [];
    }
    property bool opened: false
    property string selectedMonitor: ""
    property string draftTitle: ""
    property string renameTitle: ""
    property bool desktopAudio: true
    property bool microphone: false
    property bool dismissWhenActionCompletes: false

    function open(payloadJson) {
        opened = true;
        if (meeting)
            meeting.refresh();
        if (!recording || recording.phase === "idle" || recording.phase === "error")
            resetSetup();
        if (recording && recording.completed) {
            renameTitle = recording.title || recording.outputFilename.replace(/\.mp4$/, "");
            completionCountdown.start();
        }
    }

    function close() {
        opened = false;
        completionCountdown.stop();
        if (recording && recording.completed) {
            if (recording.actionRunning)
                dismissWhenActionCompletes = true;
            else
                recording.dismiss();
        }
    }

    function resetSetup() {
        var focused = context.compositor ? String(context.compositor.focusedOutputId || "") : "";
        selectedMonitor = monitorRows.some(function (row) {
            return monitorName(row) === focused;
        }) ? focused : monitorRows.length > 0 ? monitorName(monitorRows[0]) : "";
        draftTitle = recording && typeof recording.defaultTitle === "function" ? recording.defaultTitle() : "Recording";
        desktopAudio = recording ? recording.defaultDesktopAudio : true;
        microphone = recording ? recording.defaultMicrophone : false;
    }

    function monitorName(row) {
        return String(row && (row.name || row.id) || "");
    }

    function monitorDescription(row) {
        if (!row)
            return "Display output";
        var makeModel = [String(row.make || ""), String(row.model || "")].filter(function (value) {
            return value !== "";
        }).join(" ");
        var logical = row.logical || {};
        var modes = Array.isArray(row.modes) ? row.modes : [];
        var mode = modes[Math.max(0, Number(row.current_mode || 0))] || {};
        var width = Number(mode.width || logical.width || 0);
        var height = Number(mode.height || logical.height || 0);
        var geometry = width > 0 && height > 0 ? width + "×" + height : "";
        return [makeModel, geometry].filter(function (value) {
            return value !== "";
        }).join(" · ") || "Display output";
    }

    function startCapture() {
        if (!recording)
            return "unavailable";
        var result = recording.start(recording.recordingDirectory, selectedMonitor, draftTitle.trim(), desktopAudio, microphone);
        if (result === "started")
            closeSurface();
        return result;
    }

    function togglePauseAndClose() {
        if (!recording)
            return "unavailable";
        var result = recording.togglePause();
        if (result === "started")
            closeSurface();
        return result;
    }

    function cancelAndClose() {
        if (!recording)
            return "unavailable";
        var result = recording.cancel();
        if (result === "started")
            closeSurface();
        return result;
    }

    function finishAsMeetingAndClose() {
        if (!recording)
            return "unavailable";
        var result = recording.stopAsMeeting();
        if (result === "started")
            closeSurface();
        return result;
    }

    function runCompletedAction(action) {
        if (!recording)
            return "unavailable";
        var result = action();
        closeSurface();
        return result;
    }

    function openRecordingAndClose() {
        return runCompletedAction(function () { return recording.openRecording(); });
    }

    function openFolderAndClose() {
        return runCompletedAction(function () { return recording.openFolder(); });
    }

    function copyOutputPathAndClose() {
        return runCompletedAction(function () { return recording.copyOutputPath(); });
    }

    function closeSurface() {
        context.actions.surfaceClose("stillsuit.recording");
    }

    component RoundControl: Ui.ShellAction {
        id: control

        required property var theme
        property string iconName: ""
        property bool dangerIcon: false

        signal clicked

        accessibleFallback: iconName.replace(/-/g, " ")
        implicitWidth: 34
        implicitHeight: implicitWidth
        onActivated: clicked()

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: !control.enabled
                ? control.theme.component.control.disabled
                : control.pressed
                    ? control.theme.component.control.pressed
                    : control.hovered
                        ? control.theme.component.control.hover
                        : control.theme.component.control.background
            border.width: 1
            border.color: control.theme.component.control.outline
            opacity: control.enabled ? 1 : 0.74
        }

        Ui.ShellBusyIndicator {
            anchors.centerIn: parent
            visible: control.busy
            theme: control.theme
            sizeRole: "small"
            color: control.dangerIcon
                ? control.theme.semantic.status.danger
                : control.theme.component.control.text
        }

        Ui.ShellIcon {
            anchors.centerIn: parent
            visible: !control.busy
            theme: control.theme
            name: control.iconName
            sizeRole: "small"
            color: !control.enabled
                ? control.theme.component.control.textDisabled
                : control.dangerIcon
                    ? control.theme.semantic.status.danger
                    : control.theme.component.control.text
            role: control.dangerIcon ? "danger" : "primary"
        }
    }

    CompletionCountdown {
        id: completionCountdown
        timeoutMs: 30000
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
                return;
            if (root.opened && root.recording.completed) {
                root.renameTitle = root.recording.title;
                completionCountdown.start();
            } else if (!root.recording.completed) {
                completionCountdown.stop();
                root.dismissWhenActionCompletes = false;
            }
        }
        function onActionRunningChanged() {
            if (!root.recording || root.recording.actionRunning
                    || !root.dismissWhenActionCompletes)
                return;
            root.dismissWhenActionCompletes = false;
            if (root.recording.completed)
                root.recording.dismiss();
        }
        function onOutputPathChanged() {
            if (root.recording && root.recording.completed)
                root.renameTitle = root.recording.outputFilename.replace(/\.mp4$/, "");
        }
        function onTitleChanged() {
            if (root.recording && root.recording.completed)
                root.renameTitle = root.recording.title;
        }
    }

    Ui.ShellSurface {
        id: card
        anchors.fill: parent

        theme: root.context.theme
        kind: "panel"

        MouseArea {
            anchors.fill: parent
            onClicked: function (mouse) {
                mouse.accepted = true;
            }
        }

        ColumnLayout {
            id: panelContent
            anchors {
                fill: parent
                margins: root.context.theme.metrics.panelPadding
            }
            spacing: root.context.theme.metrics.spaceUnit * 3

            Ui.ShellPanelHeader {
                visible: !root.recording || !root.recording.active
                Layout.fillWidth: true
                theme: root.context.theme
                title: root.recording && root.recording.completed ? "Recording saved" : root.recording && root.recording.phase === "error" ? "Recording failed" : root.recording && root.recording.active ? "Screen recording" : "New recording"

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
                spacing: root.context.theme.metrics.spaceUnit * 3

                Ui.ShellSectionLabel {
                    theme: root.context.theme
                    text: "Capture output"
                }
                Ui.ShellScrollArea {
                    theme: root.context.theme
                    Layout.fillWidth: true
                    maximumHeight: root.context.theme.metrics.rowHeight * 4
                    contentHeight: monitorColumn.implicitHeight

                    ColumnLayout {
                        id: monitorColumn
                        width: parent.width
                        spacing: 2

                        Ui.ShellEmptyRow {
                            visible: root.monitorRows.length === 0
                            Layout.fillWidth: true
                            theme: root.context.theme
                            text: "No display outputs detected"
                            iconName: "record"
                        }

                        Repeater {
                            model: root.monitorRows
                            Ui.ShellRow {
                                required property var modelData
                                Layout.fillWidth: true
                                theme: root.context.theme
                                label: root.monitorName(modelData)
                                description: root.monitorDescription(modelData)
                                iconName: ""
                                reserveIconColumn: false
                                trailingIconName: selected ? "check" : ""
                                selected: root.selectedMonitor === root.monitorName(modelData)
                                accessibleName: "Capture " + label
                                onClicked: root.selectedMonitor = root.monitorName(modelData)
                            }
                        }
                    }
                }

                Ui.ShellSectionLabel {
                    theme: root.context.theme
                    text: "Recording title"
                }
                Controls.TextField {
                    id: titleInput
                    Layout.fillWidth: true
                    implicitHeight: root.context.theme.metrics.rowHeight
                    text: root.draftTitle
                    placeholderText: "Recording title"
                    selectByMouse: true
                    color: root.context.theme.semantic.content.primary
                    placeholderTextColor: root.context.theme.semantic.content.muted
                    selectionColor: root.context.theme.semantic.accent.primary
                    selectedTextColor: root.context.theme.semantic.accent.onAccent
                    font.family: root.context.theme.typography.bodyFamily
                    font.pixelSize: root.context.theme.typography.baseSize
                    leftPadding: root.context.theme.metrics.spaceUnit * 3
                    rightPadding: root.context.theme.metrics.spaceUnit * 3
                    onTextEdited: root.draftTitle = text
                    background: Rectangle {
                        radius: root.context.theme.metrics.radiusSmall
                        color: root.context.theme.component.control.background
                        border.width: 1
                        border.color: root.context.theme.component.control.outline
                    }
                }

                Ui.ShellSectionLabel {
                    theme: root.context.theme
                    text: "Audio"
                }
                Ui.ShellToggle {
                    Layout.fillWidth: true
                    theme: root.context.theme
                    label: "Desktop audio"
                    description: "Capture the selected output stream"
                    checked: root.desktopAudio
                    onToggled: function (requestedChecked) {
                        root.desktopAudio = requestedChecked;
                    }
                }
                Ui.ShellToggle {
                    Layout.fillWidth: true
                    theme: root.context.theme
                    label: "Microphone"
                    description: "Mix the default microphone into the recording"
                    checked: root.microphone
                    onToggled: function (requestedChecked) {
                        root.microphone = requestedChecked;
                    }
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
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                RoundControl {
                    id: pauseControl
                    theme: root.context.theme
                    iconName: root.recording && root.recording.paused ? "play" : "pause"
                    accessibleName: root.recording && root.recording.paused ? "Resume recording" : "Pause recording"
                    busy: root.recording && root.recording.actionRunning
                    onClicked: root.togglePauseAndClose()
                }
                RoundControl {
                    id: meetingControl
                    theme: root.context.theme
                    iconName: "agent"
                    accessibleName: "Finish as meeting"
                    busy: root.recording && root.recording.actionRunning
                    onClicked: root.finishAsMeetingAndClose()
                }
                RoundControl {
                    id: finishControl
                    theme: root.context.theme
                    iconName: "success"
                    accessibleName: "Finish recording"
                    busy: root.recording && root.recording.actionRunning
                    onClicked: root.recording.finish()
                }
                RoundControl {
                    id: cancelControl
                    theme: root.context.theme
                    iconName: "close"
                    dangerIcon: true
                    accessibleName: "Cancel recording"
                    busy: root.recording && root.recording.actionRunning
                    onClicked: root.cancelAndClose()
                }
            }

            FocusScope {
                id: completionFocus
                visible: root.recording && root.recording.completed
                Layout.fillWidth: true
                implicitHeight: completionContent.implicitHeight

                HoverHandler {
                    id: completionHover
                }

                ColumnLayout {
                    id: completionContent
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    spacing: root.context.theme.metrics.spaceUnit * 2

                    RowLayout {
                        visible: root.recording && root.recording.phase === "completed"
                        Layout.fillWidth: true
                        Controls.TextField {
                            id: renameInput
                            Layout.fillWidth: true
                            implicitHeight: root.context.theme.metrics.rowHeight
                                - root.context.theme.metrics.spaceUnit * 2
                            text: root.renameTitle
                            selectByMouse: true
                            leftPadding: root.context.theme.metrics.iconSmall
                                + root.context.theme.metrics.spaceUnit * 5
                            color: root.context.theme.semantic.content.primary
                            selectionColor: root.context.theme.semantic.accent.primary
                            selectedTextColor: root.context.theme.semantic.accent.onAccent
                            font.family: root.context.theme.typography.bodyFamily
                            font.pixelSize: root.context.theme.typography.baseSize
                            onTextEdited: root.renameTitle = text
                            onAccepted: if (root.renameTitle.trim() !== "")
                                root.recording.rename(root.renameTitle)
                            background: Rectangle {
                                radius: root.context.theme.metrics.radiusSmall
                                color: root.context.theme.component.control.background
                                border.width: 1
                                border.color: root.context.theme.component.control.outline
                            }
                            Ui.ShellIcon {
                                anchors {
                                    left: parent.left
                                    leftMargin: root.context.theme.metrics.spaceUnit * 3
                                    verticalCenter: parent.verticalCenter
                                }
                                theme: root.context.theme
                                name: "edit"
                                sizeRole: "small"
                                role: "muted"
                            }
                        }
                        Ui.ShellButton {
                            theme: root.context.theme
                            label: "Rename"
                            compact: true
                            busy: root.recording && root.recording.actionRunning
                            enabled: root.renameTitle.trim() !== ""
                            onClicked: root.recording.rename(root.renameTitle)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: root.context.theme.metrics.spaceUnit

                        Ui.ShellText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            theme: root.context.theme
                            text: (root.recording ? root.recording.elapsedText : "00:00") + " · " + (root.recording ? root.recording.outputSizeText : "0 B")
                            role: "muted"
                            font.pixelSize: root.context.theme.typography.baseSize
                                + root.context.theme.metrics.spaceUnit / 2
                            font.weight: root.context.theme.typography.weightMedium
                        }
                    }

                    RowLayout {
                        id: footerActions
                        Layout.fillWidth: true
                        spacing: root.context.theme.metrics.spaceUnit
                        Ui.ShellButton {
                            theme: root.context.theme
                            label: "Open recording"
                            iconName: "play"
                            compact: true
                            ghost: true
                            busy: root.recording && root.recording.actionRunning
                            onClicked: root.openRecordingAndClose()
                        }
                        Ui.ShellButton {
                            theme: root.context.theme
                            label: "Open folder"
                            iconName: "folder"
                            compact: true
                            ghost: true
                            busy: root.recording && root.recording.actionRunning
                            onClicked: root.openFolderAndClose()
                        }
                        Ui.ShellButton {
                            id: copyPath
                            theme: root.context.theme
                            label: root.recording && root.recording.copiedPath === root.recording.outputPath ? "Copied" : "Copy path"
                            iconName: "copy"
                            compact: true
                            ghost: true
                            accessibleName: label
                            onClicked: root.copyOutputPathAndClose()
                        }
                    }
                }
            }

            Ui.ShellStateView {
                visible: !root.recording || root.recording.phase === "error"
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                theme: root.context.theme
                mode: "error"
                iconName: "record"
                title: root.recording ? "Recording failed" : "Recording unavailable"
                message: root.recording ? root.recording.errorMessage : "Recording workflow is unavailable."
                actionLabel: "Dismiss"
                onActionRequested: if (root.recording)
                    root.recording.dismiss()
            }

            FailedMeetingJobsView {
                id: meetingQueue
                visible: rowCount > 0
                Layout.fillWidth: true
                context: root.context
                meeting: root.meeting
            }
        }
    }
}
