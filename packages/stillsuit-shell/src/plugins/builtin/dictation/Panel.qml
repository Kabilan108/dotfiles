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
        var values = dictator ? dictator.levels || [] : []
        return index < values.length && typeof values[index] === "number" ? values[index] : 0
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
    function roundedBar(ctx, x, y, width, barHeight, radius) {
        ctx.beginPath()
        ctx.moveTo(x + radius, y)
        ctx.lineTo(x + width - radius, y)
        ctx.quadraticCurveTo(x + width, y, x + width, y + radius)
        ctx.lineTo(x + width, y + barHeight - radius)
        ctx.quadraticCurveTo(x + width, y + barHeight, x + width - radius, y + barHeight)
        ctx.lineTo(x + radius, y + barHeight)
        ctx.quadraticCurveTo(x, y + barHeight, x, y + barHeight - radius)
        ctx.lineTo(x, y + radius)
        ctx.quadraticCurveTo(x, y, x + radius, y)
        ctx.closePath()
    }
    function singleLine(text) {
        return String(text || "").split(/\s+/).filter(function(part) { return part !== "" }).join(" ")
    }

    Connections {
        target: root.dictator
        ignoreUnknownSignals: true
        function onLevelsChanged() { meter.requestPaint() }
        function onVisualizerStateChanged() { meter.requestPaint() }
        function onScanPosChanged() { meter.requestPaint() }
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

                Canvas {
                    id: meter
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.barMaxHeight
                    antialiasing: true
                    onWidthChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.fillStyle = root.meterColor
                        var gap = 3
                        var barWidth = Math.max(2, (width - gap * (root.barCount - 1)) / root.barCount)
                        var active = root.state === "recording"
                        for (var index = 0; index < root.barCount; index++) {
                            var level = active
                                ? Math.pow(root.clamp((root.levelAt(index) - 0.15) / 0.85, 0, 1), 1.2)
                                : 0
                            var barHeight = root.barMinHeight + level * (root.barMaxHeight - root.barMinHeight)
                            if (root.state === "transcribing" && root.dictator && !root.reducedMotion) {
                                var pulse = root.clamp(1 - Math.abs(index - root.dictator.scanPos) / 4, 0, 1)
                                barHeight = root.barMinHeight + Math.pow(pulse, 0.8) * (root.barMaxHeight - root.barMinHeight) * 0.7
                            }
                            var x = index * (barWidth + gap)
                            var y = (root.barMaxHeight - barHeight) / 2
                            var radius = Math.min(barWidth / 2, barHeight / 2)
                            ctx.globalAlpha = active || root.state === "transcribing" ? 0.95 : 0.5
                            root.roundedBar(ctx, x, y, barWidth, barHeight, radius)
                            ctx.fill()
                        }
                        ctx.globalAlpha = 1
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
