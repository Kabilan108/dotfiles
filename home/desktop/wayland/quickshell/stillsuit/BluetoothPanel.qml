import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "ui" as Ui

Scope {
    id: root

    property bool visible: false
    property var coordinator: null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter?.enabled ?? false
    property bool scanning: Bluetooth.defaultAdapter?.discovering ?? false

    function isPaired(device) {
        return device.paired || device.connected
    }

    function isNearby(device) {
        return !device.paired && !device.connected
            && device.name !== "" && device.name !== device.address
    }

    readonly property var pairedDevices: (Bluetooth.devices?.values ?? []).filter(d => isPaired(d))
    readonly property var nearbyDevices: (Bluetooth.devices?.values ?? []).filter(d => isNearby(d))
    readonly property bool hasPaired: pairedDevices.length > 0
    readonly property bool hasNearby: nearbyDevices.length > 0

    function toggleScan() {
        if (adapter) adapter.discovering = !adapter.discovering
    }

    IpcHandler {
        target: "bluetooth"
        function toggle(): string {
            if (root.coordinator) return root.coordinator.togglePanel(root)
            root.visible = !root.visible
            return root.visible ? "open" : "closed"
        }

        function open(): string {
            if (root.coordinator) return root.coordinator.panelAction("bluetooth", "open")
            root.visible = true
            return "open"
        }

        function close(): string {
            root.visible = false
            return "closed"
        }
    }

    onVisibleChanged: {
        if (!root.visible && Bluetooth.defaultAdapter)
            Bluetooth.defaultAdapter.discovering = false
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
                        icon: Theme.icon.bluetooth
                        label: "Bluetooth"
                        on: root.enabled
                        onToggled: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
                    }

                    Column {
                        width: parent.width
                        spacing: 4
                        visible: root.enabled

                        SectionLabel {
                            text: "Paired"
                            bottomPadding: 2
                        }

                        Text {
                            width: parent.width
                            text: "No paired devices"
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            leftPadding: 8
                            topPadding: 2
                            bottomPadding: 2
                            visible: !root.hasPaired
                        }

                        ListView {
                            width: parent.width
                            height: Math.min(contentHeight, 203)
                            clip: true
                            spacing: 1
                            interactive: contentHeight > height
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.pairedDevices

                            delegate: BluetoothEntry {
                                required property var modelData
                                device: modelData
                                width: ListView.view.width
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        implicitHeight: 1
                        color: Theme.panelBorder
                        visible: root.enabled
                    }

                    Column {
                        width: parent.width
                        spacing: 4
                        visible: root.enabled

                        RowLayout {
                            width: parent.width

                            SectionLabel {
                                text: "Nearby"
                                Layout.fillWidth: true
                            }

                            Ui.StScanButton {
                                label: root.scanning ? "scanning" : "scan"
                                icon: Theme.icon.bluetooth_searching
                                busy: root.scanning
                                onClicked: root.toggleScan()
                            }
                        }

                        Text {
                            width: parent.width
                            text: root.scanning ? "searching…" : "press scan to discover devices"
                            color: root.scanning ? Theme.textSecondary : Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            leftPadding: 8
                            topPadding: 2
                            bottomPadding: 2
                            visible: !root.hasNearby
                        }

                        ListView {
                            width: parent.width
                            height: Math.min(contentHeight, 244)
                            clip: true
                            spacing: 1
                            interactive: contentHeight > height
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.nearbyDevices

                            delegate: BluetoothEntry {
                                required property var modelData
                                device: modelData
                                width: ListView.view.width
                            }
                        }
                    }
                }
            }
        }
    }
}
