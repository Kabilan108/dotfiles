import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

Rectangle {
    id: root

    required property var device

    readonly property bool connected: device.connected
    readonly property bool busy: device.state === BluetoothDeviceState.Connecting
        || device.state === BluetoothDeviceState.Disconnecting
    readonly property color accentColor: Theme.accent
    readonly property string subtitle: {
        if (device.batteryAvailable) return Math.round(device.battery * 100) + "% battery"
        if (device.name && device.name !== device.address) return device.address
        return ""
    }

    implicitHeight: 40
    radius: Theme.radiusSmall - 1
    color: mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 9

        Text {
            text: {
                const s = root.device.state
                if (s === BluetoothDeviceState.Connected) return Theme.icon.bluetooth_connected
                if (root.busy) return Theme.icon.bluetooth_searching
                return root.device.paired ? Theme.icon.bluetooth : Theme.icon.bluetooth_disabled
            }
            color: root.busy ? Theme.warning : root.connected ? root.accentColor : Theme.subtext1
            font.family: Theme.iconFamily
            font.variableAxes: ({ "FILL": root.connected ? 1 : 0, "wght": 500, "opsz": 20 })
            font.pixelSize: 15
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.device.name || root.device.address
                color: root.connected ? Theme.text : Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.subtitle
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
                visible: text !== ""
            }
        }

        Text {
            text: root.busy ? "…" : root.connected ? "connected" : "connect"
            color: root.connected ? Theme.success : root.accentColor
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: true
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.device.connected = !root.device.connected
    }
}
