import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../ui" as Ui

Scope {
    id: root

    required property var context
    required property var screen
    required property var service
    required property string outputId
    readonly property var power: context.services.get("stillsuit.power")
    property bool opened: false

    function open(payloadJson) {
        opened = true
        if (power)
            power.refresh()
    }

    function close() {
        opened = false
    }

    PanelWindow {
        id: batteryWindow

        screen: root.screen
        visible: root.opened
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        exclusiveZone: 0
        focusable: true
        color: "transparent"
        mask: Region {
            item: dismissArea
        }

        MouseArea {
            id: dismissArea
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                topMargin: root.context.theme.metrics.barHeight
            }
            acceptedButtons: Qt.AllButtons
            onClicked: root.context.actions.surfaceClose("stillsuit.battery")
        }

        Ui.ShellSurface {
            anchors {
                top: parent.top
                right: parent.right
                topMargin: root.context.theme.metrics.barHeight
                    + root.context.theme.metrics.spaceUnit
                rightMargin: root.context.theme.metrics.spaceUnit
            }
            width: root.context.theme.metrics.panelWidth
            height: content.implicitHeight
                + root.context.theme.metrics.panelPadding * 2
            theme: root.context.theme

            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) {
                    mouse.accepted = true
                }
            }

            ColumnLayout {
                id: content

                anchors {
                    fill: parent
                    margins: root.context.theme.metrics.panelPadding
                }
                spacing: root.context.theme.metrics.spaceUnit * 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.context.theme.metrics.spaceUnit * 2

                    Ui.ShellIcon {
                        theme: root.context.theme
                        name: "battery"
                        sizeRole: "large"
                        role: root._batteryRole()
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Ui.ShellText {
                            theme: root.context.theme
                            text: root.service && root.service.available
                                ? root.service.percentage + "%"
                                : "Battery unavailable"
                            sizeRole: "heading"
                            monospace: root.service && root.service.available
                            role: root.service && root.service.low
                                ? "danger"
                                : "primary"
                        }

                        Ui.ShellText {
                            theme: root.context.theme
                            text: root._stateSummary()
                            sizeRole: "caption"
                            role: "muted"
                        }
                    }

                }

                Rectangle {
                    visible: root.service && root.service.available
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                    radius: height / 2
                    color: root.context.theme.component.osd.track
                    clip: true

                    Rectangle {
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: parent.left
                        }
                        width: parent.width * Math.max(0, Math.min(1,
                            root.service ? root.service.percentage / 100 : 0))
                        radius: parent.radius
                        color: root._batteryColor()
                    }
                }

                Ui.ShellSectionLabel {
                    Layout.fillWidth: true
                    theme: root.context.theme
                    text: "Power profile"
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: root.context.theme.metrics.spaceUnit * 2

                    Repeater {
                        model: root.power ? root.power.profiles : []

                        Ui.ShellButton {
                            required property string modelData

                            theme: root.context.theme
                            label: root._profileLabel(modelData)
                            iconName: root._profileIcon(modelData)
                            active: root.power
                                && root.power.displayProfile === modelData
                            busy: root.power && root.power.busy
                                && root.power.pendingProfile === modelData
                            enabled: root.power && root.power.available
                                && !root.power.busy
                            compact: true
                            accessibleName: "Use " + label + " power profile"
                            onClicked: root.power.setProfile(modelData)
                        }
                    }
                }

                Ui.ShellStatus {
                    visible: root.power && root.power.errorMessage !== ""
                    Layout.fillWidth: true
                    theme: root.context.theme
                    status: "danger"
                    label: root.power ? root.power.errorMessage : ""
                    accessibleName: label
                }

                Ui.ShellStateView {
                    visible: !root.service || !root.service.available
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    theme: root.context.theme
                    mode: "empty"
                    iconName: "battery"
                    title: "No battery found"
                    message: "UPower did not report a present battery."
                }
            }
        }
    }

    function _batteryRole() {
        if (!service || !service.available)
            return "muted"
        if (service.low)
            return "danger"
        if (service.charging)
            return "charging"
        return "accent"
    }

    function _batteryColor() {
        if (service && service.low)
            return context.theme.semantic.status.danger
        if (service && service.charging)
            return context.theme.semantic.signal.charging
        return context.theme.semantic.accent.primary
    }

    function _stateSummary() {
        if (!service || !service.available)
            return "UPower has no battery data"
        if (service.pending)
            return "Plugged in, not charging"
        if (service.timeText === "")
            return service.stateLabel
        return service.stateLabel + ", " + service.timeText
            + (service.discharging ? " remaining" : " to full")
    }

    function _profileLabel(profile) {
        if (profile === "power-saver")
            return "Saver"
        if (profile === "performance")
            return "Performance"
        return "Balanced"
    }

    function _profileIcon(profile) {
        if (profile === "power-saver")
            return "battery"
        if (profile === "performance")
            return "power"
        return "settings"
    }
}
