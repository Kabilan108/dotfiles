import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Scope {
    id: root

    property bool visible: false
    property var coordinator: null
    property bool scanning: Bluetooth.defaultAdapter?.discovering ?? false

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
                implicitWidth: 320

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Bluetooth"
                        color: Theme.dimText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.scanning ? Theme.icon.sync : Theme.icon.refresh
                        color: root.scanning ? Theme.accent : Theme.overlay0
                        font.family: Theme.iconFamily
                        font.variableAxes: ({ "wght": 500, "opsz": 20 })
                        font.pixelSize: 16

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (Bluetooth.defaultAdapter)
                                    Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering
                            }
                        }
                    }
                }

                Repeater {
                    model: Bluetooth.devices

                    BluetoothEntry {
                        required property var modelData
                        device: modelData
                        Layout.fillWidth: true
                        visible: modelData.paired || modelData.connected
                    }
                }

                Text {
                    text: "No paired devices"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    Layout.alignment: Qt.AlignHCenter
                    visible: {
                        for (let i = 0; i < Bluetooth.devices.values.length; i++) {
                            const d = Bluetooth.devices.values[i]
                            if (d.paired || d.connected) return false
                        }
                        return true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.surface0
                    visible: root.scanning
                }

                Text {
                    text: "Nearby"
                    color: Theme.dimText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    visible: root.scanning
                }

                Flickable {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(nearbyLayout.implicitHeight, 250)
                    contentHeight: nearbyLayout.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    visible: root.scanning

                    ColumnLayout {
                        id: nearbyLayout
                        width: parent.width
                        spacing: Theme.paddingSmall

                        Repeater {
                            model: Bluetooth.devices

                            BluetoothEntry {
                                required property var modelData
                                device: modelData
                                Layout.fillWidth: true
                                visible: !modelData.paired && !modelData.connected
                                    && modelData.name !== "" && modelData.name !== modelData.address
                            }
                        }

                        Text {
                            text: "Scanning..."
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            Layout.alignment: Qt.AlignHCenter
                            visible: {
                                for (let i = 0; i < Bluetooth.devices.values.length; i++) {
                                    const d = Bluetooth.devices.values[i]
                                    if (!d.paired && !d.connected && d.name !== "" && d.name !== d.address)
                                        return false
                                }
                                return true
                            }
                        }
                    }
                }
            }
        }
    }
}
