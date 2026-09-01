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
    readonly property string displayIconName: _iconName()
    readonly property int panelVerticalPadding: Math.max(0,
        context.theme.metrics.panelPadding - context.theme.metrics.spaceUnit)
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
                + root.panelVerticalPadding * 2
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
                    leftMargin: root.context.theme.metrics.panelPadding
                    rightMargin: root.context.theme.metrics.panelPadding
                    topMargin: root.panelVerticalPadding
                    bottomMargin: root.panelVerticalPadding
                }
                spacing: root.context.theme.metrics.spaceUnit

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.context.theme.metrics.spaceUnit * 3

                    Rectangle {
                        visible: root.service && root.service.available
                        Layout.fillWidth: true
                        Layout.preferredHeight: 14
                        radius: root.context.theme.metrics.radiusSmall
                        color: root.context.theme.component.osd.track
                        clip: true

                        Rectangle {
                            id: batteryFill

                            anchors {
                                top: parent.top
                                bottom: parent.bottom
                                left: parent.left
                            }
                            width: parent.width * Math.max(0, Math.min(1,
                                root.service ? root.service.percentage / 100 : 0))
                            radius: parent.radius
                            color: root._batteryColor()
                            clip: true

                            Repeater {
                                model: Math.ceil(batteryFill.width / 9) + 2

                                Rectangle {
                                    required property int index

                                    x: index * 9 - 5
                                    y: -batteryFill.height / 2
                                    width: 1
                                    height: batteryFill.height * 2
                                    rotation: 28
                                    color: root.context.theme.semantic.accent.onAccent
                                    opacity: 0.22
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 112
                        spacing: 1

                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            spacing: root.context.theme.metrics.spaceUnit + 2

                            Ui.ShellIcon {
                                theme: root.context.theme
                                name: root.displayIconName
                                font.pixelSize:
                                    root.context.theme.metrics.iconMedium * 2
                                role: root._batteryRole()
                            }

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
                        }

                        Ui.ShellText {
                            Layout.alignment: Qt.AlignRight
                            theme: root.context.theme
                            text: root._stateSummary()
                            sizeRole: "body"
                            role: "muted"
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
                    spacing: root.context.theme.metrics.spaceUnit * 2

                    Repeater {
                        model: root.power ? root.power.profiles : []

                        Ui.ShellButton {
                            id: profileButton

                            required property string modelData

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            theme: root.context.theme
                            label: ""
                            iconName: ""
                            active: root.power
                                && root.power.displayProfile === modelData
                            busy: root.power && root.power.busy
                                && root.power.pendingProfile === modelData
                            enabled: root.power && root.power.available
                            interactive: enabled && !root.power.busy
                            compact: true
                            accessibleName: "Use " + root._profileLabel(modelData)
                                + " power profile"
                            onClicked: root.power.setProfile(modelData)

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                visible: !profileButton.busy

                                Ui.ShellIcon {
                                    Layout.topMargin: 1
                                    theme: root.context.theme
                                    name: root._profileIcon(profileButton.modelData)
                                    sizeRole: "small"
                                    color: profileButton.active
                                        ? root.context.theme.component.control.onActive
                                        : profileButton.enabled
                                            ? root.context.theme.component.control.text
                                            : root.context.theme.component.control.textDisabled
                                }

                                Ui.ShellText {
                                    theme: root.context.theme
                                    text: root._profileLabel(profileButton.modelData)
                                    sizeRole: "label"
                                    color: profileButton.active
                                        ? root.context.theme.component.control.onActive
                                        : profileButton.enabled
                                            ? root.context.theme.component.control.text
                                            : root.context.theme.component.control.textDisabled
                                }
                            }
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

    function _iconName() {
        if (!service || !service.available)
            return "battery-question"
        if (service.charging)
            return "battery-charging"
        if (service.low && service.percentage <= 8)
            return "battery-alert"
        if (service.percentage >= 95)
            return "battery-level-full"
        if (service.percentage >= 80)
            return "battery-level-6"
        if (service.percentage >= 62)
            return "battery-level-5"
        if (service.percentage >= 45)
            return "battery-level-4"
        if (service.percentage >= 30)
            return "battery-level-3"
        if (service.percentage >= 18)
            return "battery-level-2"
        if (service.percentage >= 8)
            return "battery-level-1"
        return "battery-level-0"
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
