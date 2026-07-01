import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "ui" as Ui

Scope {
    id: root

    property bool visible: false
    property var coordinator: null
    property var batteryDevice: UPower.displayDevice
    property var profiles: []
    property string activeProfile: ""

    readonly property bool batteryPresent: batteryDevice !== null && batteryDevice.isPresent && batteryDevice.percentage > 0
    readonly property int percentageValue: batteryPresent ? Math.round(batteryDevice.percentage * 100) : 0
    readonly property string percentageText: batteryPresent ? percentageValue + "%" : ""
    readonly property string batteryState: stateName(batteryDevice ? batteryDevice.state : null)
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
        const seconds = batteryPresent ? (onBattery ? batteryDevice.timeToEmpty : batteryDevice.timeToFull) : 0
        if (batteryPresent && isFinite(seconds) && seconds > 0 && seconds < 86400) return formatDuration(seconds)

        return "—"
    }
    readonly property string timeCaption: {
        if (!batteryPresent) return ""
        if (batteryState === "fully-charged") return "Fully charged"
        if (batteryState === "holding") return "Holding charge"
        if (timeDisplay === "—") return ""
        return onBattery ? timeDisplay + " left" : timeDisplay + " to full"
    }

    function toggle() {
        visible = !visible
    }

    function refresh() {
        if (!profilesProc.running) profilesProc.running = true
    }

    function stateName(state) {
        if (state === UPowerDeviceState.Charging) return "charging"
        if (state === UPowerDeviceState.Discharging) return "discharging"
        if (state === UPowerDeviceState.Empty) return "empty"
        if (state === UPowerDeviceState.FullyCharged) return "fully-charged"
        if (state === UPowerDeviceState.PendingCharge) return "pending-charge"
        if (state === UPowerDeviceState.PendingDischarge) return "pending-discharge"
        return "unknown"
    }

    function formatDuration(seconds) {
        const totalMinutes = Math.round(seconds / 60)
        const hours = Math.floor(totalMinutes / 60)
        const minutes = totalMinutes % 60
        if (hours <= 0) return minutes + "m"
        return hours + "h " + String(minutes).padStart(2, "0") + "m"
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
                implicitWidth: 372
                padding: 14
                color: Theme.panelChrome

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: Theme.radiusSmall
                        color: Theme.panelSurface
                        border.width: Theme.borderWidth
                        border.color: Theme.panelBorder

                        Text {
                            anchors.centerIn: parent
                            text: root.batteryGlyph
                            color: root.batteryColor
                            font.family: Theme.iconFamily
                            font.variableAxes: ({ "FILL": 0, "wght": 500, "opsz": 24 })
                            font.pixelSize: 25
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            Layout.alignment: Qt.AlignBottom
                            text: root.batteryPresent ? String(root.percentageValue) : "--"
                            color: root.batteryLow ? Theme.urgent : Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: 34
                            font.bold: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 5
                            visible: root.batteryPresent
                            text: "%"
                            color: root.batteryLow ? Theme.urgent : Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: root.stateLabel
                            color: root.batteryLow ? Theme.urgent : Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignRight
                            visible: root.timeCaption !== ""
                            text: root.timeCaption
                            color: Theme.textTertiary
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
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

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: profileRow.implicitHeight + 8
                    radius: Theme.radiusSmall
                    color: Theme.panelSurface
                    border.width: Theme.borderWidth
                    border.color: Theme.panelBorder

                    RowLayout {
                        id: profileRow
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        Repeater {
                            model: root.profiles

                            Ui.StButton {
                                required property string modelData
                                Layout.fillWidth: true
                                subtle: true
                                horizontalPadding: 6
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

}
