import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "ui" as Ui

Scope {
    id: root

    property bool visible: false
    property var coordinator: null
    property var batteryInfo: ({})
    property var profiles: []
    property string activeProfile: ""

    readonly property string percentageText: batteryInfo.percentage || ""
    readonly property int percentageValue: parseInt(String(percentageText).replace("%", ""), 10) || 0
    readonly property string batteryState: String(batteryInfo.state || "").toLowerCase()
    readonly property bool batteryPresent: percentageText !== ""
    readonly property bool onBattery: batteryState === "discharging"
    readonly property bool batteryLow: batteryPresent && onBattery && percentageValue <= 20
    readonly property real fraction: batteryPresent ? Math.max(0, Math.min(1, percentageValue / 100)) : 0
    readonly property string stateLabel: {
        if (!batteryPresent) return "No battery"
        if (batteryState === "fully-charged") return "Fully charged"
        if (batteryState === "holding") return "Holding"
        if (batteryState === "charging") return "Charging"
        if (onBattery) return "On battery"
        return "Plugged in"
    }

    function toggle() {
        visible = !visible
    }

    function refresh() {
        if (!batteryProc.running) batteryProc.running = true
        if (!profilesProc.running) profilesProc.running = true
    }

    function parseKeyValue(raw) {
        const next = ({})
        const lines = String(raw || "").split("\n")
        for (let i = 0; i < lines.length; i++) {
            const idx = lines[i].indexOf("\t")
            if (idx <= 0) continue
            next[lines[i].substring(0, idx)] = lines[i].substring(idx + 1).trim()
        }
        if (Object.keys(next).length > 0) batteryInfo = next
    }

    function parseProfiles(raw) {
        const list = []
        let active = ""
        const lines = String(raw || "").split("\n")
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (!line) continue
            const parts = line.split("\t")
            list.push(parts[0])
            if (parts[1] === "1") active = parts[0]
        }
        if (list.length > 0) profiles = list
        if (active) activeProfile = active
    }

    function setProfile(profile) {
        if (!profile || actionProc.running) return
        actionProc.command = ["powerprofilesctl", "set", profile]
        actionProc.running = true
    }

    function profileLabel(profile) {
        const text = String(profile || "")
        return text.charAt(0).toUpperCase() + text.slice(1)
    }

    onVisibleChanged: if (visible) refresh()
    Component.onCompleted: refresh()

    IpcHandler {
        target: "power"

        function toggle(): string {
            if (root.coordinator) return root.coordinator.togglePanel(root)
            root.toggle()
            return root.visible ? "open" : "closed"
        }

        function open(): string {
            if (root.coordinator) return root.coordinator.panelAction("power", "open")
            root.visible = true
            return "open"
        }

        function close(): string {
            root.visible = false
            return "closed"
        }
    }

    Process {
        id: batteryProc
        command: ["bash", "-lc", "stillctl-battery-status --shell 2>/dev/null || omarchy-battery-status --shell 2>/dev/null || true"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseKeyValue(text)
        }
    }

    Process {
        id: profilesProc
        command: ["bash", "-lc", "powerprofilesctl list 2>/dev/null | awk '/^\\s*[* ]\\s*[a-zA-Z0-9-]+:$/ { active=($1==\"*\"); gsub(/^[*[:space:]]+|:$/,\"\",$0); print $0 \"\\t\" (active ? 1 : 0) }' | tac"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseProfiles(text)
        }
    }

    Process {
        id: actionProc
        onExited: root.refresh()
    }

    Timer {
        interval: root.visible ? 5000 : 30000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }

    LazyLoader {
        active: root.visible

        PanelWindow {
            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            margins {
                top: Theme.barHeight + Theme.screenMargin + Theme.panelGap
            }
            exclusiveZone: 0
            focusable: false
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onClicked: root.visible = false
            }

            MouseArea {
                anchors.fill: panel
                onClicked: {}
            }

            PopupPanel {
                id: panel
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.rightMargin: Theme.screenMargin
                implicitWidth: 390

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "Battery"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTitle
                            font.bold: true
                        }

                        Text {
                            text: root.stateLabel.toUpperCase()
                            color: Theme.dimText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            font.letterSpacing: 2
                        }
                    }

                    Text {
                        text: root.batteryPresent ? Math.round(root.fraction * 100) + "%" : "--"
                        color: root.batteryLow ? Theme.urgent : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 40
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    radius: height / 2
                    color: Theme.osdTrack

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(parent.height, parent.width * root.fraction)
                        height: parent.height
                        radius: parent.radius
                        color: root.onBattery ? Theme.success : Theme.warning

                        Behavior on width {
                            NumberAnimation { duration: Theme.animationMedium; easing.type: Easing.OutCubic }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 22
                    rowSpacing: 8

                    PowerInfoPair { label: "Battery size"; value: root.batteryInfo.size || "—" }
                    PowerInfoPair { label: root.onBattery ? "Time left" : "Time to full"; value: root.batteryInfo.time || "—" }
                    PowerInfoPair { label: "Threshold"; value: root.batteryInfo.threshold || "—" }
                    PowerInfoPair { label: root.onBattery ? "Discharging" : "Charging"; value: root.batteryInfo.rate || "—" }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.panelBorder
                }

                Text {
                    text: "POWER PROFILE"
                    color: Theme.dimText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    font.letterSpacing: 2
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.profiles

                        Ui.StButton {
                            required property string modelData
                            Layout.fillWidth: true
                            text: root.profileLabel(modelData)
                            active: root.activeProfile === modelData
                            onClicked: root.setProfile(modelData)
                        }
                    }
                }
            }
        }
    }

}
