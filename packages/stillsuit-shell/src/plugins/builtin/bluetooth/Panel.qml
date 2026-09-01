import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../ui" as Ui

Scope {
    id: root

    required property var context
    required property var service
    required property var screen
    required property string outputId

    PanelWindow {
        id: panel

        screen: root.screen
        visible: false
        color: "transparent"
        exclusiveZone: 0
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        mask: Region {
            y: root.context.theme.metrics.barHeight
            width: panel.width
            height: Math.max(0, panel.height - y)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.context.actions.surfaceClose("stillsuit.bluetooth")
        }

    Ui.ShellSurface {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: root.context.theme.metrics.barHeight
                + root.context.theme.metrics.spaceUnit * 2
            rightMargin: root.context.theme.metrics.spaceUnit * 2
        }
        width: root.context.theme.metrics.panelWidth
        height: Math.min(540, parent.height - anchors.topMargin
            - root.context.theme.metrics.spaceUnit * 2)
        theme: root.context.theme
        kind: "panel"

        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) { mouse.accepted = true }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.context.theme.metrics.panelPadding
            spacing: 10

            Ui.ShellText {
                Layout.fillWidth: true
                theme: root.context.theme
                text: "Bluetooth"
                sizeRole: "heading"
            }

            Ui.ShellToggle {
                Layout.fillWidth: true
                theme: root.context.theme
                label: "Bluetooth"
                description: root.service && root.service.enabled
                    ? "BlueZ adapter is enabled"
                    : "BlueZ adapter is disabled"
                checked: Boolean(root.service && root.service.enabled)
                busy: root.service && root.service.operation === "adapter"
                interactive: Boolean(root.service && root.service.available)
                onToggled: function(requested) { root.service.setEnabled(requested) }
            }

            Ui.ShellStatus {
                Layout.fillWidth: true
                visible: root.service && root.service.lastError !== ""
                theme: root.context.theme
                status: "danger"
                iconName: "danger"
                label: root.service ? root.service.lastError : ""
            }

            Ui.ShellStateView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.service || !root.service.available
                theme: root.context.theme
                mode: "error"
                title: "Bluetooth unavailable"
                message: "No BlueZ adapter is available."
                iconName: "bluetooth"
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.service && root.service.available && root.service.enabled
                clip: true
                contentWidth: width
                contentHeight: deviceColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: deviceColumn

                    width: parent.width
                    spacing: 6

                    Ui.ShellSectionLabel {
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: "Connected"
                    }

                    Ui.ShellStateView {
                        Layout.fillWidth: true
                        visible: root.service.connectedDevices.length === 0
                        theme: root.context.theme
                        mode: "empty"
                        title: "No connected devices"
                        message: "Choose a paired or available device below."
                        iconName: "bluetooth"
                    }

                    Repeater {
                        model: root.service.connectedDevices

                        delegate: DeviceRow {
                            required property var modelData
                            Layout.fillWidth: true
                            device: modelData
                            group: "connected"
                        }
                    }

                    Ui.ShellSectionLabel {
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: "Paired"
                    }

                    Ui.ShellStateView {
                        Layout.fillWidth: true
                        visible: root.service.pairedDevices.length === 0
                        theme: root.context.theme
                        mode: "empty"
                        title: "No disconnected paired devices"
                        iconName: "bluetooth"
                    }

                    Repeater {
                        model: root.service.pairedDevices

                        delegate: DeviceRow {
                            required property var modelData
                            Layout.fillWidth: true
                            device: modelData
                            group: "paired"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Ui.ShellSectionLabel {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            text: "Available"
                        }

                        Ui.ShellButton {
                            theme: root.context.theme
                            label: "Scan"
                            iconName: "refresh"
                            compact: true
                            ghost: true
                            busy: Boolean(root.service && root.service.scanning)
                            accessibleName: "Scan for Bluetooth devices"
                            onClicked: root.service.scan()
                        }
                    }

                    Ui.ShellStateView {
                        Layout.fillWidth: true
                        visible: root.service.availableDevices.length === 0
                        theme: root.context.theme
                        mode: root.service.scanning ? "loading" : "empty"
                        title: root.service.scanning ? "Scanning" : "No available devices"
                        message: root.service.scanning
                            ? "BlueZ is discovering nearby devices."
                            : "Press Scan to discover devices."
                        iconName: "bluetooth"
                    }

                    Repeater {
                        model: root.service.availableDevices

                        delegate: DeviceRow {
                            required property var modelData
                            Layout.fillWidth: true
                            device: modelData
                            group: "available"
                        }
                    }
                }
            }
        }
    }
    }

    component DeviceRow: Ui.ShellRow {
        id: row

        required property var device
        required property string group
        readonly property string stateLabel: root.service.statusFor(device)
        readonly property string failure: root.service.failureFor(device)
        readonly property string battery: root.service.batteryText(device)

        theme: root.context.theme
        label: root.service.deviceName(device)
        description: failure !== "" ? failure
            : battery !== "" ? battery
            : group === "available" ? String(device.address || "Ready to pair")
            : "Paired with BlueZ"
        iconName: group === "connected" ? "headphones" : "bluetooth"
        trailingText: stateLabel
        selected: group === "connected"
        danger: failure !== ""
        busy: ["pairing", "connecting", "disconnecting", "forgetting",
            "selecting audio"].indexOf(stateLabel) !== -1
        interactive: root.service.operation === "idle" && failure === ""
        accessibleName: label + ", " + stateLabel
        onClicked: root.service.toggle(device)

        Ui.ShellButton {
            visible: row.group !== "available"
            theme: root.context.theme
            label: "Forget"
            iconName: "delete"
            compact: true
            ghost: true
            destructive: true
            interactive: root.service.operation === "idle"
            accessibleName: "Forget " + row.label
            onClicked: root.service.forgetDevice(row.device)
        }
    }

    function open(payloadJson) {
        panel.visible = true
    }

    function close() {
        if (service)
            service.stopScan()
        panel.visible = false
    }
}
