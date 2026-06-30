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
    readonly property color batteryColor: batteryLow ? Theme.urgent
        : batteryState === "charging" ? Theme.charge
        : Theme.success
    readonly property string batteryGlyph: {
        if (!batteryPresent) return Theme.icon.battery_android_question
        if (batteryState === "charging") return Theme.icon.electrical_services
        const f = fraction
        if (f >= 0.95) return Theme.icon.battery_android_full
        if (f >= 0.80) return Theme.icon.battery_android_6
        if (f >= 0.62) return Theme.icon.battery_android_5
        if (f >= 0.45) return Theme.icon.battery_android_4
        if (f >= 0.30) return Theme.icon.battery_android_3
        if (f >= 0.18) return Theme.icon.battery_android_2
        if (f >= 0.08) return Theme.icon.battery_android_1
        return Theme.icon.battery_android_0
    }
    // When full/holding while plugged in, the charge rate approaches zero and the
    // estimator reports an absurd time (e.g. 130h). Treat anything >= 24h as no estimate.
    readonly property string timeDisplay: {
        const raw = String(batteryInfo.time || "").trim()
        if (raw === "") return "—"
        const hours = parseInt(raw, 10)
        if (!isNaN(hours) && hours >= 24) return "—"
        return raw
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
                implicitWidth: 400
                padding: 16
                color: Theme.panelChrome

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 11

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.batteryGlyph
                        color: root.batteryColor
                        font.family: Theme.iconFamily
                        font.variableAxes: ({ "FILL": 0, "wght": 500, "opsz": 20 })
                        font.pixelSize: 24
                    }

                    SectionLabel {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.stateLabel
                        fontSize: 14
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.batteryPresent ? Math.round(root.fraction * 100) + "%" : "--"
                        color: root.batteryLow ? Theme.urgent : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 38
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
                        color: root.batteryColor

                        Behavior on width {
                            NumberAnimation { duration: Theme.animationMedium; easing.type: Easing.OutCubic }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 7
                    columns: 2
                    columnSpacing: 22
                    rowSpacing: 8

                    PowerInfoPair { label: "Battery size"; value: root.batteryInfo.size || "—" }
                    PowerInfoPair {
                        label: root.onBattery ? "Time left" : "Time to full"
                        value: root.timeDisplay
                    }
                    PowerInfoPair { label: "Threshold"; value: root.batteryInfo.threshold || "—" }
                    PowerInfoPair { label: root.onBattery ? "Discharging" : "Charging"; value: root.batteryInfo.rate || "—" }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 7
                    Layout.bottomMargin: 7
                    implicitHeight: 1
                    color: Theme.panelBorder
                }

                SectionLabel {
                    text: "Power Profile"
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
