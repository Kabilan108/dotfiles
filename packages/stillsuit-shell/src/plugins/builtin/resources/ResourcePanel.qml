import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../ui" as Ui

Scope {
    id: root

    required property var context
    required property var screen
    required property string outputId
    required property var service
    property bool opened: false

    function open(payloadJson) {
        opened = true
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
            onClicked: root.context.actions.surfaceClose("stillsuit.resources")
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
                        name: "cpu"
                        sizeRole: "large"
                        role: "accent"
                    }

                    Ui.ShellText {
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: "System resources"
                        sizeRole: "heading"
                    }
                }

                Ui.ShellSectionLabel {
                    Layout.fillWidth: true
                    theme: root.context.theme
                    text: "Current usage"
                }

                Ui.ShellSurface {
                    Layout.fillWidth: true
                    Layout.preferredHeight: metricsRows.implicitHeight + 8
                    theme: root.context.theme
                    kind: "raised"

                    ColumnLayout {
                        id: metricsRows

                        anchors {
                            fill: parent
                            margins: 4
                        }
                        spacing: 0

                        Ui.ShellRow {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            interactive: false
                            iconName: "cpu"
                            label: "CPU"
                            description: "Aggregate utilization"

                            Ui.ShellText {
                                theme: root.context.theme
                                text: root._percent(root.service
                                    ? root.service.cpuPercent : null)
                                sizeRole: "caption"
                                monospace: true
                                color: root._usageColor(root.service
                                    ? root.service.cpuPercent : null)
                            }
                        }

                        Ui.ShellRow {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            interactive: false
                            iconName: "memory"
                            label: "Memory"
                            description: "Used physical memory"

                            Ui.ShellText {
                                theme: root.context.theme
                                text: root._percent(root.service
                                    ? root.service.memoryPercent : null)
                                sizeRole: "caption"
                                monospace: true
                                color: root._usageColor(root.service
                                    ? root.service.memoryPercent : null)
                            }
                        }
                    }
                }

                Ui.ShellText {
                    Layout.fillWidth: true
                    theme: root.context.theme
                    text: "Updated every 3 seconds"
                    sizeRole: "caption"
                    role: "muted"
                }
            }
        }
    }

    function _percent(value) {
        if (value === undefined || value === null || value === "")
            return "--"
        return Math.round(Number(value)) + "%"
    }

    function _usageColor(value) {
        var band = service ? service.usageBand(value) : ""
        var colors = context.theme.component.resources
        return band !== "" && colors && colors[band] !== undefined
            ? colors[band] : context.theme.semantic.content.secondary
    }
}
