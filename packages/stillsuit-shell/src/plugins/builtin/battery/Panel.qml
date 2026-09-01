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
        if (service)
            service.refreshDetails()
    }

    function close() {
        opened = false
    }

    PanelWindow {
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

        MouseArea {
            anchors.fill: parent
            onClicked: root.context.actions.surfaceClose("stillsuit.battery")
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

                    Ui.ShellStatus {
                        visible: root.service && root.service.pending
                        theme: root.context.theme
                        status: "warning"
                        label: "Pending"
                        compact: true
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
                    text: "Battery details"
                }

                Ui.ShellSurface {
                    Layout.fillWidth: true
                    Layout.preferredHeight: details.implicitHeight + 8
                    theme: root.context.theme
                    kind: "raised"

                    ColumnLayout {
                        id: details

                        anchors {
                            fill: parent
                            margins: 4
                        }
                        spacing: 0

                        Ui.ShellRow {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            interactive: false
                            iconName: "battery"
                            label: "Health"
                            description: root._capacityDescription()
                            trailingText: root._percentOrUnavailable(
                                root.service ? root.service.healthPercent : null)
                        }

                        Ui.ShellRow {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            interactive: false
                            iconName: "repeat"
                            label: "Charge cycles"
                            trailingText: root._numberOrUnavailable(
                                root.service ? root.service.cycleCount : null)
                        }

                        Ui.ShellRow {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            interactive: false
                            iconName: "power"
                            label: "Live power draw"
                            trailingText: root._wattsOrUnavailable(
                                root.service ? root.service.powerDrawWatts : null)
                        }

                        Ui.ShellRow {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            interactive: false
                            iconName: "settings"
                            label: "Charge thresholds"
                            trailingText: root._thresholds()
                        }
                    }
                }

                Ui.ShellSectionLabel {
                    Layout.fillWidth: true
                    theme: root.context.theme
                    text: "Power profile"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.context.theme.metrics.spaceUnit

                    Repeater {
                        model: root.power ? root.power.profiles : []

                        Ui.ShellButton {
                            required property string modelData

                            Layout.fillWidth: true
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
        if (service.pending)
            return "warning"
        return "accent"
    }

    function _batteryColor() {
        if (service && service.low)
            return context.theme.semantic.status.danger
        if (service && service.charging)
            return context.theme.semantic.signal.charging
        if (service && service.pending)
            return context.theme.semantic.status.warning
        return context.theme.semantic.accent.primary
    }

    function _stateSummary() {
        if (!service || !service.available)
            return "UPower has no battery data"
        if (service.timeText === "")
            return service.stateLabel
        return service.stateLabel + ", " + service.timeText
            + (service.discharging ? " remaining" : " to full")
    }

    function _capacityDescription() {
        if (!service || service.capacityWh === null)
            return "Full capacity unavailable"
        if (service.designCapacityWh === null)
            return service.capacityWh.toFixed(1) + " Wh full capacity"
        return service.capacityWh.toFixed(1) + " of "
            + service.designCapacityWh.toFixed(1) + " Wh"
    }

    function _percentOrUnavailable(value) {
        return value === null || value === undefined
            ? "Unavailable"
            : Math.round(Number(value)) + "%"
    }

    function _numberOrUnavailable(value) {
        return value === null || value === undefined
            ? "Unavailable"
            : String(Math.round(Number(value)))
    }

    function _wattsOrUnavailable(value) {
        return value === null || value === undefined
            ? "Unavailable"
            : Number(value).toFixed(1) + " W"
    }

    function _thresholds() {
        if (!service || !service.chargeThresholdSupported)
            return "Unavailable"
        var start = service.chargeStartThreshold
        var end = service.chargeEndThreshold
        if (start !== null && end !== null)
            return Math.round(start) + "% / " + Math.round(end) + "%"
        if (end !== null)
            return "Stop at " + Math.round(end) + "%"
        return "Supported"
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
