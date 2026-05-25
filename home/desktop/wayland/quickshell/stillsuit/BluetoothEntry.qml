import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

RowLayout {
    id: root

    required property var device

    spacing: 8

    Text {
        text: {
            const s = root.device.state
            if (s === BluetoothDeviceState.Connected) return "󰂱"
            if (s === BluetoothDeviceState.Connecting) return "󰂳"
            if (s === BluetoothDeviceState.Disconnecting) return "󰂳"
            return root.device.paired ? "󰂯" : "󰂲"
        }
        color: {
            const s = root.device.state
            if (s === BluetoothDeviceState.Connected) return Theme.accent
            if (s === BluetoothDeviceState.Connecting || s === BluetoothDeviceState.Disconnecting)
                return Theme.yellow
            return Theme.overlay0
        }
        font.family: Theme.fontFamily
        font.pixelSize: 16
    }

    Text {
        Layout.fillWidth: true
        text: root.device.name || root.device.address
        color: root.device.connected ? Theme.text : Theme.dimText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
    }

    Text {
        text: Math.round(root.device.battery * 100) + "%"
        color: root.device.battery < 0.2 ? Theme.red : Theme.dimText
        font.family: Theme.fontFamily
        font.pixelSize: 9
        visible: root.device.batteryAvailable
    }

    Text {
        text: {
            const s = root.device.state
            if (s === BluetoothDeviceState.Connecting) return "..."
            if (s === BluetoothDeviceState.Disconnecting) return "..."
            return root.device.connected ? "Disconnect" : "Connect"
        }
        color: root.device.connected ? Theme.red : Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: 9

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.device.connected = !root.device.connected
        }
    }
}
