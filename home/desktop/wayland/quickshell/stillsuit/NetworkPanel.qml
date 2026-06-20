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

    readonly property var wifiDevice: findWifiDevice()
    readonly property var wifiNetworks: sortedWifiNetworks()
    readonly property var connectedNetwork: connectedWifiNetwork()

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

    function networkIcon(network) {
        const strength = Math.round((network ? network.signalStrength || 0 : 0) * 100)
        if (strength >= 80) return Theme.icon.network_wifi
        if (strength >= 60) return Theme.icon.network_wifi_3_bar
        if (strength >= 40) return Theme.icon.network_wifi_2_bar
        if (strength >= 20) return Theme.icon.network_wifi_1_bar
        return Theme.icon.signal_wifi_0_bar
    }

    function networkMeta(network) {
        if (!network) return ""
        if (network.connected) return "connected"
        if (actionSsid === network.name) return "connecting"
        if (network.known) return "known"
        if (isOpenNetwork(network)) return "open"
        return "secured"
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

    onVisibleChanged: {
        if (visible) startScan()
        else if (wifiDevice) wifiDevice.scannerEnabled = false
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

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Network"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitle
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Ui.StButton {
                        text: root.scanning ? "scanning" : "scan"
                        icon: Theme.icon.refresh
                        active: root.scanning
                        onClicked: root.startScan()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.connectedNetwork ? root.connectedNetwork.name : "No Wi-Fi connection"
                    color: root.connectedNetwork ? Theme.text : Theme.dimText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.panelBorder
                }

                Text {
                    text: "NETWORKS"
                    color: Theme.dimText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    font.letterSpacing: 2
                }

                Repeater {
                    model: root.wifiNetworks.slice(0, 10)

                    Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 42
                        radius: Theme.radiusSmall
                        color: mouse.containsMouse ? Theme.panelSurfaceHover : "transparent"
                        border.width: modelData.connected ? Theme.borderWidth : 0
                        border.color: modelData.connected ? Theme.accent : Theme.panelBorder

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Text {
                                text: root.networkIcon(modelData)
                                color: modelData.connected ? Theme.accent : Theme.dimText
                                font.family: Theme.iconFamily
                                font.variableAxes: ({ "wght": 500, "opsz": 20 })
                                font.pixelSize: 15
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name || "hidden network"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeMedium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: root.networkMeta(modelData)
                                    color: Theme.dimText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }

                            Text {
                                visible: !root.canConnect(modelData) && !modelData.connected
                                text: Theme.icon.lock
                                color: Theme.mutedText
                                font.family: Theme.iconFamily
                                font.variableAxes: ({ "wght": 500, "opsz": 20 })
                                font.pixelSize: 13
                            }
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: root.canConnect(modelData) || modelData.connected ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.activateNetwork(modelData)
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.wifiNetworks.length === 0
                    text: root.wifiDevice ? "No networks found" : "Wi-Fi unavailable"
                    color: Theme.dimText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }
}
