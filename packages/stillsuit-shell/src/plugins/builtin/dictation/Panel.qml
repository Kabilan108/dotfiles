import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../ui" as Ui

Item {
    id: root
    readonly property bool hostedPanel: true
    implicitWidth: root.context.theme.metrics.panelWidth
    implicitHeight: content.implicitHeight + root.context.theme.metrics.panelPadding * 2
    visible: false

    required property var context
    required property var service
    required property var screen
    required property string outputId
    readonly property var theme: context.theme
    readonly property QtObject dictator: service ? service.dictator : null
    readonly property string state: service ? service.state : "idle"
    readonly property bool live: service && service.connected
    readonly property int barCount: dictator ? dictator.barCount : 23
    readonly property real barMaxHeight: 26
    readonly property real barMinHeight: 3
    readonly property bool reducedMotion: context.settings
        && context.settings.values
        && context.settings.values.reducedMotion === true
    readonly property color meterColor: state === "error"
        ? theme.semantic.status.danger
        : state === "recording"
            ? theme.semantic.signal.microphone
            : state === "transcribing" || state === "typing"
                ? theme.semantic.status.info
                : theme.semantic.content.disabled
    readonly property string statusText: !service || !service.configured
        ? "Dictator is not configured"
        : !live
            ? "Daemon not running"
            : state === "recording"
                ? "Recording · " + String(dictator.durationText || "")
                : state === "transcribing"
                    ? "Transcribing…"
                    : state === "typing"
                        ? "Pasting…"
                        : state === "error"
                            ? "Last recording failed"
                            : "Ready"
    property bool opened: false
    // keepLoaded panels exist on every output; only the opened one follows
    // the meter so hidden panels do no work per scan tick.
    readonly property var levels: opened && dictator ? dictator.levels || [] : []
    readonly property real scanPos: opened && dictator ? dictator.scanPos : 0

    function open(payloadJson) {
        opened = true
        if (service) service.refreshRecent()
    }
    function close() { opened = false }
    function closeSurface() { context.actions.surfaceClose("stillsuit.dictation") }

    function toggle() { return service ? service.toggle() : "unavailable" }
    function cancel() { return service ? service.cancel() : "unavailable" }
    function openWindowAndClose() {
        var result = service ? service.openWindow() : "unavailable"
        if (result === "started") closeSurface()
        return result
    }
    function copyRow(row) {
        return service ? service.copyText(row ? row.text : "") : "unavailable"
    }
    function levelAt(index) {
        return index < levels.length && typeof levels[index] === "number" ? levels[index] : 0
    }
    function meterBarHeight(index) {
        if (state === "transcribing" && dictator && !reducedMotion) {
            var pulse = clamp(1 - Math.abs(index - scanPos) / 4, 0, 1)
            return barMinHeight + Math.pow(pulse, 0.8) * (barMaxHeight - barMinHeight) * 0.7
        }
        var level = state === "recording"
            ? Math.pow(clamp((levelAt(index) - 0.15) / 0.85, 0, 1), 1.2)
            : 0
        return barMinHeight + level * (barMaxHeight - barMinHeight)
    }
    function clamp(value, minimum, maximum) { return Math.min(Math.max(value, minimum), maximum) }
    function timeLabel(timestamp) {
        var date = new Date(String(timestamp || ""))
        if (isNaN(date.getTime())) return ""
        return Qt.formatTime(date, "HH:mm")
    }
    function durationLabel(milliseconds) {
        var seconds = Math.max(0, Number(milliseconds || 0)) / 1000
        var minutes = Math.floor(seconds / 60)
        var rest = seconds - minutes * 60
        return minutes + ":" + (rest < 10 ? "0" : "") + rest.toFixed(1)
    }
    function singleLine(text) {
        return String(text || "").split(/\s+/).filter(function(part) { return part !== "" }).join(" ")
    }

    Ui.ShellSurface {
        anchors.fill: parent
        theme: root.theme
        kind: "panel"

        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) { mouse.accepted = true }
        }

        ColumnLayout {
            id: content
            anchors { fill: parent; margins: root.theme.metrics.panelPadding }
            spacing: root.theme.metrics.spaceUnit * 3

            Ui.ShellPanelHeader {
                Layout.fillWidth: true
                theme: root.theme
                title: "Dictation"
                subtitle: root.statusText
                Ui.ShellButton {
                    theme: root.theme
                    label: "Open"
                    iconName: "settings"
                    compact: true
                    ghost: true
                    accessibleName: "Open the Dictator app"
                    visible: root.service && root.service.guiPath !== ""
                    onClicked: root.openWindowAndClose()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.theme.metrics.spaceUnit * 3

                Ui.ShellAction {
                    id: recordButton
                    readonly property bool recordingNow: root.state === "recording"
                    implicitWidth: 44
                    implicitHeight: 44
                    enabled: root.service && root.service.canToggle
                    accessibleName: recordingNow ? "Stop and transcribe" : "Start recording"
                    onActivated: root.toggle()

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: !recordButton.enabled
                            ? root.theme.component.control.disabled
                            : recordButton.recordingNow
                                ? root.theme.component.control.background
                                : root.theme.semantic.accent.primary
                        border.width: recordButton.recordingNow ? 1 : 0
                        border.color: root.theme.component.control.outline
                        opacity: recordButton.enabled ? (recordButton.pressed ? 0.85 : 1) : 0.6
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        radius: recordButton.recordingNow ? 3 : 7
                        color: recordButton.recordingNow
                            ? root.theme.semantic.signal.microphone
                            : root.theme.semantic.accent.onAccent
                    }
                }

                Item {
                    id: meter
                    readonly property real gap: 3
                    readonly property real barWidth: Math.max(2, (width - gap * (root.barCount - 1)) / root.barCount)

                    Layout.fillWidth: true
                    Layout.preferredHeight: root.barMaxHeight
                    opacity: root.state === "recording" || root.state === "transcribing" ? 0.95 : 0.5

                    Repeater {
                        model: root.barCount

                        Rectangle {
                            required property int index

                            x: index * (meter.barWidth + meter.gap)
                            y: (root.barMaxHeight - height) / 2
                            width: meter.barWidth
                            height: root.meterBarHeight(index)
                            radius: Math.min(width, height) / 2
                            antialiasing: true
                            color: root.meterColor
                        }
                    }
                }

                Ui.ShellButton {
                    visible: root.service && root.service.canCancel
                    theme: root.theme
                    label: ""
                    iconName: "close"
                    compact: true
                    destructive: true
                    accessibleName: "Cancel recording"
                    onClicked: root.cancel()
                }
            }

            Ui.ShellStatus {
                visible: root.service && root.service.errorMessage !== ""
                Layout.fillWidth: true
                theme: root.theme
                status: "danger"
                label: root.service ? root.service.errorMessage : ""
                wrap: true
            }

            Ui.ShellSectionLabel {
                visible: root.service && root.service.recent.length > 0
                Layout.fillWidth: true
                theme: root.theme
                text: "Recent"
            }

            Ui.ShellEmptyRow {
                visible: root.service && root.service.recent.length === 0
                Layout.fillWidth: true
                theme: root.theme
                iconName: "microphone"
                text: root.service && root.service.recentStatus === "error"
                    ? "Could not read history"
                    : "No recordings yet"
                error: root.service && root.service.recentStatus === "error"
            }

            Repeater {
                model: root.service ? root.service.recent : []

                Ui.ShellRow {
                    id: row
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    theme: root.theme
                    reserveIconColumn: false
                    label: root.singleLine(modelData.text) || "No speech was transcribed"
                    description: root.timeLabel(modelData.timestamp) + " · " + root.durationLabel(modelData.durationMs)
                    trailingIconName: "copy"
                    accessibleName: "Copy transcript from " + root.timeLabel(modelData.timestamp)
                    onClicked: root.copyRow(modelData)
                }
            }
        }
    }
}
