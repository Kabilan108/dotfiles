import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Scope {
    id: root

    property bool visible: false
    property bool scanning: Bluetooth.defaultAdapter?.discovering ?? false

    IpcHandler {
        target: "bluetooth"
        function toggle(): void {
            root.visible = !root.visible
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
                right: true
            }
            margins {
                top: 40
                right: 12
            }
            exclusiveZone: 0
            focusable: true
            implicitWidth: panel.implicitWidth
            implicitHeight: panel.implicitHeight
            color: "transparent"

            PopupPanel {
                id: panel
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
                        text: root.scanning ? "󰑙" : "󰑐"
                        color: root.scanning ? Theme.accent : Theme.overlay0
                        font.family: Theme.fontFamily
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
