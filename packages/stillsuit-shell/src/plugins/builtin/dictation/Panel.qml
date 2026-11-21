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
    readonly property string statusText: !service || !service.configured
                                         ? "Dictator is not configured" : !live
                                           ? "Daemon not running" : state === "recording"
                                             ? "Recording · " + String(dictator.durationText || "") :
                                               state === "transcribing" ? "Transcribing…" : state
                                                                          === "typing" ? "Pasting…" :
                                                                                         state === "error"
                                                                                         ? "Last recording failed" :
                                                                                           "Ready"

    function open(payloadJson) {
        if (service)
            service.refreshRecent()
    }
    function close() {
    }
    function closeSurface() {
        context.actions.surfaceClose("stillsuit.dictation")
    }

    function openWindowAndClose() {
        var result = service ? service.openWindow() : "unavailable"
        if (result === "started")
            closeSurface()
        return result
    }
    function copyRow(row) {
        return service ? service.copyText(row ? row.text : "") : "unavailable"
    }
    function timeLabel(timestamp) {
        var date = new Date(String(timestamp || ""))
        if (isNaN(date.getTime()))
            return ""
        return Qt.formatTime(date, "HH:mm")
    }
    function durationLabel(milliseconds) {
        var seconds = Math.max(0, Number(milliseconds || 0)) / 1000
        var minutes = Math.floor(seconds / 60)
        var rest = seconds - minutes * 60
        return minutes + ":" + (rest < 10 ? "0" : "") + rest.toFixed(1)
    }
    function singleLine(text) {
        return String(text || "").split(/\s+/).filter(function (part) {
            return part !== ""
        }).join(" ")
    }

    Ui.ShellSurface {
        anchors.fill: parent
        theme: root.theme
        kind: "panel"

        MouseArea {
            anchors.fill: parent
            onClicked: function (mouse) {
                mouse.accepted = true
            }
        }

        ColumnLayout {
            id: content
            anchors {
                fill: parent
                margins: root.theme.metrics.panelPadding
            }
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
                      ? "Could not read history" : "No recordings yet"
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
                    description: root.timeLabel(modelData.timestamp) + " · " + root.durationLabel(
                                     modelData.durationMs)
                    trailingIconName: "copy"
                    accessibleName: "Copy transcript from " + root.timeLabel(modelData.timestamp)
                    onClicked: root.copyRow(modelData)
                }
            }
        }
    }
}
