// Adapted from Omarchy Quattro v4.0.0's slot-based bar structure.
// Copyright (c) David Heinemeier Hansson. Licensed under MIT.
// Stillsuit changes: narrow host injection, grouped theme roles, and no
// widget-owned services, timers, sockets, or IPC handlers.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../../ui" as Ui

Scope {
    id: root

    required property var context

    // The host owns component loading and supplies only ready registrations.
    // Each immutable record has component, context, manifest, defaultSection,
    // allowMultiple, optional service, and an optional release(message)
    // callback. The bar must not receive a catalog or composition root.
    property var widgetRegistrations: []

    // The host supplies Quickshell.screens. It remains the only source of
    // actual output objects, while the bar stays independent of host globals.
    property var outputScreens: []

    readonly property bool shadowMode: context
        && context.settings
        && context.settings.values
        && context.settings.values.shadowMode === true
    readonly property real barHeight: context.theme.metrics.barHeight
    readonly property real outerGap: context.theme.metrics.barOuterGap
    readonly property real exclusionZone: barHeight + outerGap

    function recordsFor(section) {
        var records = []
        var seenSingle = ({})
        var source = Array.isArray(widgetRegistrations) ? widgetRegistrations : []
        for (var index = 0; index < source.length; index++) {
            var record = source[index]
            if (!record || !record.component || !record.manifest || !record.manifest.id)
                continue
            var targetSection = record.defaultSection || "center"
            if (targetSection !== section)
                continue
            var pluginId = String(record.manifest.id)
            if (record.allowMultiple !== true && seenSingle[pluginId] === true)
                continue
            seenSingle[pluginId] = true
            records.push({ registration: record, sequence: index, pluginId: pluginId })
        }
        records.sort(function(left, right) {
            if (left.pluginId !== right.pluginId)
                return left.pluginId < right.pluginId ? -1 : 1
            return left.sequence - right.sequence
        })
        return records
    }

    Variants {
        model: root.outputScreens

        PanelWindow {
            id: barWindow
            required property var modelData
            readonly property string outputId: modelData && modelData.name
                ? String(modelData.name)
                : ""

            screen: modelData
            visible: true
            anchors {
                top: true
                left: true
                right: true
            }
            margins {
                top: root.outerGap
                left: root.outerGap
                right: root.outerGap
            }
            implicitHeight: root.barHeight
            exclusiveZone: root.shadowMode ? 0 : root.exclusionZone
            color: "transparent"
            WlrLayershell.namespace: "stillsuit.bar"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Ui.ShellSurface {
                anchors.fill: parent
                theme: root.context.theme
                kind: "bar"
                radius: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.context.theme.metrics.barInnerGap
                    anchors.rightMargin: root.context.theme.metrics.barInnerGap
                    spacing: root.context.theme.metrics.barInnerGap

                    RowLayout {
                        id: leftSlot
                        objectName: "stillsuit-bar-left"
                        spacing: root.context.theme.metrics.spaceUnit
                        Layout.alignment: Qt.AlignVCenter
                        Repeater {
                            model: root.recordsFor("left")
                            WidgetSlot {
                                required property var modelData
                                registration: modelData.registration
                                outputId: barWindow.outputId
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        id: centerSlot
                        objectName: "stillsuit-bar-center"
                        spacing: root.context.theme.metrics.spaceUnit
                        Layout.alignment: Qt.AlignVCenter
                        Repeater {
                            model: root.recordsFor("center")
                            WidgetSlot {
                                required property var modelData
                                registration: modelData.registration
                                outputId: barWindow.outputId
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        id: rightSlot
                        objectName: "stillsuit-bar-right"
                        spacing: root.context.theme.metrics.spaceUnit
                        Layout.alignment: Qt.AlignVCenter
                        Repeater {
                            model: root.recordsFor("right")
                            WidgetSlot {
                                required property var modelData
                                registration: modelData.registration
                                outputId: barWindow.outputId
                            }
                        }
                    }
                }

                Ui.ShellText {
                    anchors.centerIn: parent
                    visible: centerSlot.children.length === 0
                    theme: root.context.theme
                    text: "Stillsuit"
                    role: "muted"
                    sizeRole: "caption"
                }
            }
        }
    }
}
