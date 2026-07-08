import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "ui" as Ui

Scope {
    id: root

    property bool visible: false
    property var coordinator: null
    property bool scanning: false
    property string actionSsid: ""
    property var vpnConnections: []
    property string vpnBusyUuid: ""

    readonly property var wifiDevice: findWifiDevice()
    readonly property var wifiNetworks: sortedWifiNetworks()
    readonly property var connectedNetwork: connectedWifiNetwork()
    readonly property var availableNetworks: wifiNetworks.filter(n => !n.connected && !n.known).slice(0, 14)
    readonly property var savedNetworks: wifiNetworks.filter(n => n.known && !n.connected)
    readonly property bool wifiEnabled: Networking.wifiEnabled

    function toggle() {
        visible = !visible
    }

    function findWifiDevice() {
        const devices = Networking.devices ? Networking.devices.values : []
        for (let i = 0; i < devices.length; i++) {
            if (devices[i] && devices[i].type === DeviceType.Wifi) return devices[i]
        }
        return null
    }

    function connectedWifiNetwork() {
        const networks = wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
        for (let i = 0; i < networks.length; i++) {
            if (networks[i] && networks[i].connected) return networks[i]
        }
        return null
    }

    function sortedWifiNetworks() {
        const networks = wifiDevice && wifiDevice.networks ? wifiDevice.networks.values.slice() : []
        networks.sort((a, b) => {
            if (!!a.connected !== !!b.connected) return a.connected ? -1 : 1
            if (!!a.known !== !!b.known) return a.known ? -1 : 1
            return Number(b.signalStrength || 0) - Number(a.signalStrength || 0)
        })
        return networks
    }

    function isOpenNetwork(network) {
        return network && network.security === WifiSecurityType.Open
    }

    function canConnect(network) {
        return !!network && !network.connected && (network.known || isOpenNetwork(network))
    }

    function signalLevel(network) {
        const strength = network ? network.signalStrength || 0 : 0
        if (strength <= 0) return 0
        if (strength >= 0.8) return 4
        if (strength >= 0.55) return 3
        if (strength >= 0.3) return 2
        return 1
    }

    function connectedSubtitle(network) {
        if (!network) return ""
        const pct = Math.round((network.signalStrength || 0) * 100)
        return pct + "% · " + (isOpenNetwork(network) ? "open" : "secured")
    }

    function activateNetwork(network) {
        if (!network || actionSsid !== "") return
        actionSsid = network.name || ""

        if (network.connected) {
            network.disconnect()
        } else if (canConnect(network)) {
            network.connect()
        }

        actionTimeout.restart()
    }

    function startScan() {
        if (!wifiDevice) return
        scanning = true
        wifiDevice.scannerEnabled = false
        scanRestart.restart()
    }

    function splitTerse(line, maxFields) {
        const fields = []
        let current = ""
        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (ch === "\\" && i + 1 < line.length) {
                current += line[i + 1]
                i++
            } else if (ch === ":" && fields.length < maxFields - 1) {
                fields.push(current)
                current = ""
            } else {
                current += ch
            }
        }
        fields.push(current)
        return fields
    }

    function parseVpnList(text) {
        const conns = []
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            if (lines[i] === "") continue
            const parts = splitTerse(lines[i], 4)
            if (parts.length < 4) continue
            const type = parts[1]
            if (type !== "vpn" && type !== "wireguard") continue
            conns.push({ uuid: parts[0], type: type, active: parts[2] === "yes", name: parts[3] })
        }
        conns.sort((a, b) => a.active === b.active
            ? a.name.localeCompare(b.name)
            : (a.active ? -1 : 1))
        vpnConnections = conns
    }

    function refreshVpns() {
        vpnListProc.running = true
    }

    function toggleVpn(vpn) {
        if (!vpn || vpnBusyUuid !== "") return
        vpnBusyUuid = vpn.uuid
        vpnToggleProc.command = ["nmcli", "--wait", "20", "connection",
            vpn.active ? "down" : "up", "uuid", vpn.uuid]
        vpnToggleProc.running = true
    }

    onVisibleChanged: {
        if (visible) {
            startScan()
            refreshVpns()
        } else if (wifiDevice) {
            wifiDevice.scannerEnabled = false
        }
    }

    Component.onCompleted: refreshVpns()

    component WifiRow: Rectangle {
        id: rowRoot

        required property var network
        property string mode: "available"

        readonly property bool connected: network?.connected ?? false
        readonly property bool secured: !root.isOpenNetwork(network)
        readonly property bool connecting: root.actionSsid === (network?.name || "")

        implicitHeight: 40
        radius: Theme.radiusSmall - 1
        color: rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 9

            Ui.StSignalBars {
                Layout.alignment: Qt.AlignVCenter
                level: root.signalLevel(rowRoot.network)
                barColor: rowRoot.connected ? Theme.accent : Theme.textSecondary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: rowRoot.network?.name || "hidden network"
                    color: rowRoot.connected ? Theme.textPrimary : Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.connectedSubtitle(rowRoot.network)
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    visible: rowRoot.mode === "connected"
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 7

                Text {
                    text: Theme.icon.lock
                    color: Theme.textTertiary
                    font.family: Theme.iconFamily
                    font.variableAxes: ({ "wght": 500, "opsz": 20 })
                    font.pixelSize: 12
                    visible: rowRoot.secured && !rowRoot.connected
                }

                Text {
                    text: rowRoot.connecting ? "connecting"
                        : rowRoot.connected ? "connected"
                        : rowRoot.mode === "saved" ? "saved" : "connect"
                    color: rowRoot.connected ? Theme.success
                        : rowRoot.mode === "saved" && !rowRoot.connecting ? Theme.textSecondary
                        : Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.canConnect(rowRoot.network) || rowRoot.connected
                ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.activateNetwork(rowRoot.network)
        }
    }

    component VpnRow: Rectangle {
        id: vpnRowRoot

        required property var vpn

        readonly property bool active: vpn?.active ?? false
        readonly property bool busy: root.vpnBusyUuid === (vpn?.uuid || "")

        implicitHeight: 40
        radius: Theme.radiusSmall - 1
        color: vpnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 9

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: Theme.icon.vpn_lock
                color: vpnRowRoot.active ? Theme.accent : Theme.textSecondary
                font.family: Theme.iconFamily
                font.variableAxes: ({ "FILL": vpnRowRoot.active ? 1 : 0, "wght": 500, "opsz": 20 })
                font.pixelSize: 15
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: vpnRowRoot.vpn?.name || "vpn"
                    color: vpnRowRoot.active ? Theme.textPrimary : Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: vpnRowRoot.vpn?.type === "wireguard" ? "wireguard" : "vpn"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    visible: vpnRowRoot.active
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: vpnRowRoot.busy ? (vpnRowRoot.active ? "disconnecting" : "connecting")
                    : vpnRowRoot.active ? "connected" : "connect"
                color: vpnRowRoot.active && !vpnRowRoot.busy ? Theme.success : Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.bold: true
            }
        }

        MouseArea {
            id: vpnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleVpn(vpnRowRoot.vpn)
        }
    }

    IpcHandler {
        target: "network"

        function toggle(): string {
            if (root.coordinator) return root.coordinator.togglePanel(root)
            root.toggle()
            return root.visible ? "open" : "closed"
        }

        function open(): string {
            if (root.coordinator) return root.coordinator.panelAction("network", "open")
            root.visible = true
            return "open"
        }

        function close(): string {
            root.visible = false
            return "closed"
        }
    }

    Timer {
        id: scanRestart
        interval: 120
        repeat: false
        onTriggered: {
            if (root.wifiDevice) root.wifiDevice.scannerEnabled = true
            scanDone.restart()
        }
    }

    Timer {
        id: scanDone
        interval: 3200
        repeat: false
        onTriggered: root.scanning = false
    }

    Timer {
        id: actionTimeout
        interval: 9000
        repeat: false
        onTriggered: root.actionSsid = ""
    }

    Process {
        id: vpnListProc
        command: ["nmcli", "-t", "-f", "UUID,TYPE,ACTIVE,NAME", "connection", "show"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseVpnList(text)
        }
    }

    Process {
        id: vpnToggleProc
        onExited: {
            root.vpnBusyUuid = ""
            root.refreshVpns()
        }
    }

    Timer {
        interval: 4000
        running: root.visible
        repeat: true
        onTriggered: root.refreshVpns()
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
                implicitWidth: 360
                padding: 16
                color: Theme.panelChrome

                Column {
                    id: panelBody
                    Layout.fillWidth: true
                    spacing: 14

                    Ui.StToggle {
                        width: parent.width
                        icon: Theme.icon.wifi
                        label: "Wi-Fi"
                        on: root.wifiEnabled
                        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                    }

                    Column {
                        width: parent.width
                        spacing: 4
                        visible: root.wifiEnabled && root.connectedNetwork !== null

                        SectionLabel {
                            text: "Connected"
                            bottomPadding: 2
                        }

                        WifiRow {
                            width: parent.width
                            network: root.connectedNetwork
                            mode: "connected"
                            visible: root.connectedNetwork !== null
                        }
                    }

                    Rectangle {
                        width: parent.width
                        implicitHeight: 1
                        color: Theme.panelBorder
                        visible: root.wifiEnabled
                    }

                    Column {
                        width: parent.width
                        spacing: 4
                        visible: root.wifiEnabled

                        RowLayout {
                            width: parent.width

                            SectionLabel {
                                text: "Available"
                                Layout.fillWidth: true
                            }

                            Ui.StScanButton {
                                label: root.scanning ? "scanning" : "refresh"
                                busy: root.scanning
                                onClicked: root.startScan()
                            }
                        }

                        Text {
                            width: parent.width
                            text: root.scanning ? "scanning for networks…"
                                : root.wifiDevice ? "no networks found" : "wi-fi unavailable"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            leftPadding: 8
                            topPadding: 2
                            bottomPadding: 2
                            visible: root.availableNetworks.length === 0
                        }

                        ListView {
                            width: parent.width
                            height: Math.min(contentHeight, 244)
                            clip: true
                            spacing: 1
                            interactive: contentHeight > height
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.availableNetworks

                            delegate: WifiRow {
                                required property var modelData
                                width: ListView.view.width
                                network: modelData
                                mode: "available"
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        implicitHeight: 1
                        color: Theme.panelBorder
                        visible: root.wifiEnabled && root.savedNetworks.length > 0
                    }

                    Column {
                        width: parent.width
                        spacing: 4
                        visible: root.wifiEnabled && root.savedNetworks.length > 0

                        SectionLabel {
                            text: "Saved"
                            bottomPadding: 2
                        }

                        ListView {
                            width: parent.width
                            height: Math.min(contentHeight, 162)
                            clip: true
                            spacing: 1
                            interactive: contentHeight > height
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.savedNetworks

                            delegate: WifiRow {
                                required property var modelData
                                width: ListView.view.width
                                network: modelData
                                mode: "saved"
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        implicitHeight: 1
                        color: Theme.panelBorder
                        visible: root.vpnConnections.length > 0
                    }

                    Column {
                        width: parent.width
                        spacing: 4
                        visible: root.vpnConnections.length > 0

                        SectionLabel {
                            text: "VPN"
                            bottomPadding: 2
                        }

                        ListView {
                            width: parent.width
                            height: Math.min(contentHeight, 162)
                            clip: true
                            spacing: 1
                            interactive: contentHeight > height
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.vpnConnections

                            delegate: VpnRow {
                                required property var modelData
                                width: ListView.view.width
                                vpn: modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
