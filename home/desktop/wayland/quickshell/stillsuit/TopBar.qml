import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Io

Scope {
    id: root

    required property var niri
    required property var recording
    property var audioPanel: null
    property var bluetoothPanel: null
    property var networkPanel: null
    property var notificationPanel: null
    property var powerPanel: null
    property var panelCoordinator: null
    property string cpuPercent: ""
    property string memoryPercent: ""

    property bool visible: true

    function togglePanel(panel) {
        if (!panel) return
        if (panelCoordinator && panelCoordinator.togglePanel) panelCoordinator.togglePanel(panel)
    }

    function notificationCount() {
        if (!notificationPanel || !notificationPanel.trackedCount) return 0
        return notificationPanel.trackedCount
    }

    function networkIcon() {
        if (wiredConnected()) return Theme.icon.lan
        const wifi = wifiDevice()
        if (!wifi) return Theme.icon.signal_wifi_off
        const connected = connectedWifiNetwork()
        if (!connected) return Theme.icon.wifi_off
        const strength = Math.round((connected.signalStrength || 0) * 100)
        if (strength >= 80) return Theme.icon.network_wifi
        if (strength >= 60) return Theme.icon.network_wifi_3_bar
        if (strength >= 40) return Theme.icon.network_wifi_2_bar
        if (strength >= 20) return Theme.icon.network_wifi_1_bar
        return Theme.icon.signal_wifi_0_bar
    }

    function wiredConnected() {
        const devices = Networking.devices ? Networking.devices.values : []
        for (let i = 0; i < devices.length; i++) {
            if (devices[i] && devices[i].type === DeviceType.Wired && devices[i].connected) return true
        }
        return false
    }

    function wifiDevice() {
        const devices = Networking.devices ? Networking.devices.values : []
        for (let i = 0; i < devices.length; i++) {
            if (devices[i] && devices[i].type === DeviceType.Wifi) return devices[i]
        }
        return null
    }

    function connectedWifiNetwork() {
        const device = wifiDevice()
        const networks = device && device.networks ? device.networks.values : []
        for (let i = 0; i < networks.length; i++) {
            if (networks[i] && networks[i].connected) return networks[i]
        }
        return null
    }

    function bluetoothActive() {
        const devices = Bluetooth.devices ? Bluetooth.devices.values : []
        for (let i = 0; i < devices.length; i++) {
            if (devices[i] && devices[i].connected) return true
        }
        return false
    }

    function audioPercent() {
        const sink = Pipewire.defaultAudioSink
        if (!sink || !sink.audio) return ""
        return Math.round(Math.max(0, Math.min(1.5, sink.audio.volume)) * 100) + "%"
    }

    function batteryPercent() {
        return root.powerPanel ? root.powerPanel.percentageText : ""
    }

    function batteryLow() {
        return !!(root.powerPanel && root.powerPanel.batteryLow)
    }

    function batteryPresent() {
        return !!(root.powerPanel && root.powerPanel.batteryPresent)
    }

    function batteryCharging() {
        return !!(root.powerPanel && root.powerPanel.batteryState === "charging")
    }

    function batteryIcon() {
        if (!root.powerPanel || !root.powerPanel.batteryPresent) return Theme.icon.battery_android_question

        if (root.batteryCharging()) return Theme.icon.electrical_services

        const percent = root.powerPanel.percentageValue || 0
        if (percent >= 95) return Theme.icon.battery_android_full
        if (percent >= 80) return Theme.icon.battery_android_6
        if (percent >= 62) return Theme.icon.battery_android_5
        if (percent >= 45) return Theme.icon.battery_android_4
        if (percent >= 30) return Theme.icon.battery_android_3
        if (percent >= 18) return Theme.icon.battery_android_2
        if (percent >= 8) return Theme.icon.battery_android_1
        return Theme.icon.battery_android_0
    }

    function parseSystemStats(raw) {
        const lines = String(raw || "").split("\n")
        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split("\t")
            if (parts.length < 2) continue
            if (parts[0] === "cpu") root.cpuPercent = parts[1].trim()
            if (parts[0] === "mem") root.memoryPercent = parts[1].trim()
        }
    }

    function refreshSystemStats() {
        if (!systemStatsProc.running) systemStatsProc.running = true
    }

    Component.onCompleted: refreshSystemStats()

    Process {
        id: systemStatsProc
        command: ["bash", "-lc", "read _ user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat\n"
            + "total1=$((user + nice + system + idle + iowait + irq + softirq + steal))\n"
            + "idle1=$((idle + iowait))\n"
            + "sleep 0.2\n"
            + "read _ user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 guest2 guest_nice2 < /proc/stat\n"
            + "total2=$((user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2 + steal2))\n"
            + "idle2v=$((idle2 + iowait2))\n"
            + "dt=$((total2 - total1))\n"
            + "di=$((idle2v - idle1))\n"
            + "cpu=$((dt > 0 ? (100 * (dt - di) + dt / 2) / dt : 0))\n"
            + "mem=$(awk '/MemTotal:/ { total=$2 } /MemAvailable:/ { avail=$2 } END { if (total > 0) printf \"%d\", ((total - avail) * 100 + total / 2) / total; else print 0 }' /proc/meminfo)\n"
            + "printf 'cpu\\t%s%%\\nmem\\t%s%%\\n' \"$cpu\" \"$mem\"\n"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseSystemStats(text)
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refreshSystemStats()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            readonly property string outputName: root.niri.outputName(modelData)
            readonly property bool focusedOutput: root.niri.isFocusedOutput(outputName)

            screen: modelData
            visible: root.visible
            anchors {
                top: true
                left: true
                right: true
            }
            margins {
                top: Theme.screenMargin
                left: Theme.screenMargin
                right: Theme.screenMargin
            }
            exclusiveZone: Theme.barHeight + Theme.screenMargin + Theme.panelGap
            implicitHeight: Theme.barHeight
            color: "transparent"
            WlrLayershell.namespace: "stillsuit-bar"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: Theme.panelBgStrong
                border.width: Theme.borderWidth
                border.color: barWindow.focusedOutput ? Theme.accent : Theme.panelBorder
                clip: true

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 9
                    spacing: 8

                    RowLayout {
                        id: leftCluster
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 8

                        WorkspaceStrip {
                            niri: root.niri
                            outputName: barWindow.outputName
                        }

                        Rectangle {
                            implicitWidth: 1
                            implicitHeight: 18
                            color: Theme.panelBorder
                        }

                        ColumnStrip {
                            niri: root.niri
                            outputName: barWindow.outputName
                        }

                        RecordingIndicator {
                            visible: root.recording.active
                            controller: root.recording
                            Layout.leftMargin: 6
                            onClicked: root.recording.toggle()
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 8

                        BarCluster {
                            icon: Theme.icon.memory_alt
                            label: root.memoryPercent
                            compact: true
                            clickable: false
                        }

                        BarCluster {
                            icon: Theme.icon.memory
                            label: root.cpuPercent
                            compact: true
                            clickable: false
                        }

                        Rectangle {
                            implicitWidth: 1
                            implicitHeight: 18
                            color: Theme.panelBorder
                        }

                        BarCluster {
                            icon: root.networkIcon()
                            active: barWindow.focusedOutput && root.networkPanel && root.networkPanel.visible
                            compact: true
                            onClicked: root.togglePanel(root.networkPanel)
                        }

                        BarCluster {
                            icon: root.bluetoothActive() ? Theme.icon.bluetooth_connected : Theme.icon.bluetooth_disabled
                            active: barWindow.focusedOutput && root.bluetoothPanel && root.bluetoothPanel.visible
                            compact: true
                            onClicked: root.togglePanel(root.bluetoothPanel)
                        }

                        Rectangle {
                            implicitWidth: 1
                            implicitHeight: 18
                            color: Theme.panelBorder
                        }

                        BarCluster {
                            icon: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted ? Theme.icon.volume_off : Theme.icon.volume_up
                            label: root.audioPercent()
                            active: barWindow.focusedOutput && root.audioPanel && root.audioPanel.visible
                            onClicked: root.togglePanel(root.audioPanel)
                        }

                        Rectangle {
                            implicitWidth: 1
                            implicitHeight: 18
                            color: Theme.panelBorder
                        }

                        BarCluster {
                            icon: root.notificationPanel && root.notificationPanel.doNotDisturb
                                ? Theme.icon.notifications_off
                                : root.notificationCount() > 0 ? Theme.icon.notifications_unread : Theme.icon.notifications
                            label: root.notificationCount() > 0 ? String(root.notificationCount()) : ""
                            accentColor: Theme.accent
                            active: barWindow.focusedOutput && root.notificationPanel && root.notificationPanel.centerVisible
                            highlightLabel: root.notificationCount() > 0
                            onClicked: root.togglePanel(root.notificationPanel)
                        }

                        Rectangle {
                            visible: root.batteryPresent()
                            implicitWidth: 1
                            implicitHeight: 18
                            color: Theme.panelBorder
                        }

                        BarCluster {
                            visible: root.batteryPresent()
                            icon: root.batteryIcon()
                            label: root.batteryPercent()
                            accentColor: root.batteryCharging() ? Theme.charge : Theme.accent
                            emphasizeState: root.batteryCharging()
                            alert: root.batteryLow()
                            active: barWindow.focusedOutput && root.powerPanel && root.powerPanel.visible
                            onClicked: root.togglePanel(root.powerPanel)
                        }
                    }
                }

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    color: Theme.accent2
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                    text: Qt.formatDateTime(clock.now, "MM-dd-yyyy  HH:mm:ss")
                }
            }
        }
    }

    Timer {
        id: clock
        property date now: new Date()
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: now = new Date()
    }

    component WorkspaceStrip: Row {
        id: strip
        required property var niri
        required property string outputName

        spacing: 5

        Repeater {
            model: strip.niri.workspacesForOutput(strip.outputName)

            Rectangle {
                required property var modelData
                readonly property bool activeWorkspace: modelData && modelData.is_active
                readonly property bool urgentWorkspace: modelData && modelData.is_urgent
                readonly property bool agentWorkspace: modelData && modelData.name === "agent"

                width: activeWorkspace ? 18 : 6
                height: 6
                radius: height / 2
                color: urgentWorkspace ? Theme.urgent
                    : agentWorkspace ? Theme.mauve
                    : activeWorkspace ? Theme.accent
                    : Theme.textMuted
                opacity: activeWorkspace || urgentWorkspace ? 1 : agentWorkspace ? 0.8 : 0.55

                Behavior on width {
                    NumberAnimation { duration: Theme.animationFast; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast }
                }
            }
        }
    }

    component ColumnStrip: Row {
        id: strip
        required property var niri
        required property string outputName

        readonly property var workspace: niri.activeWorkspaceForOutput(outputName)
        readonly property int count: niri.columnCountForWorkspace(workspace)
        readonly property int focusedColumn: niri.focusedColumnForWorkspace(workspace)

        spacing: 4

        Repeater {
            model: strip.count

            Rectangle {
                required property int index
                readonly property bool focusedColumn: index + 1 === strip.focusedColumn

                width: focusedColumn ? 15 : 6
                height: 10
                radius: 2
                color: focusedColumn ? Theme.accent : Theme.textMuted
                opacity: focusedColumn ? 1 : 0.6

                Behavior on width {
                    NumberAnimation { duration: Theme.animationFast; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
