import QtQuick
import "../../../ui" as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property var service
    required property string outputId

    theme: context.theme
    iconName: "bluetooth"
    label: service && service.connectedDevices.length > 1
        ? String(service.connectedDevices.length)
        : ""
    active: Boolean(service && service.connected)
    busy: Boolean(service && service.operation !== "idle")
    accessibleName: !service || !service.available ? "Bluetooth unavailable"
        : !service.enabled ? "Bluetooth disabled"
        : service.connectedDevices.length === 1
            ? "Bluetooth connected to " + service.deviceName(service.connectedDevices[0])
            : service.connectedDevices.length > 1
                ? service.connectedDevices.length + " Bluetooth devices connected"
                : "Bluetooth enabled, no device connected"
    onClicked: context.actions.surfaceToggle("stillsuit.bluetooth", "")
}
