// Adapted from Omarchy Quattro v4.0.0's slot-based bar structure.
// Copyright (c) David Heinemeier Hansson. Licensed under MIT.
// Stillsuit changes: narrow host injection, grouped theme roles, and no
// widget-owned services, timers, sockets, or IPC handlers.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    required property var context

    // The host owns component loading and supplies only ready registrations.
    // Each record has component, context, manifest, defaultSection,
    // allowMultiple, and optional service. The bar must not receive a catalog
    // or composition root.
    property var widgetRegistrations: []

    // The host supplies Quickshell.screens. It remains the only source of
    // actual output objects, while the bar stays independent of host globals.
    property var outputScreens: []

    readonly property bool shadowMode: context
        && context.settings
        && context.settings.values
        && context.settings.values.shadowMode === true
    readonly property real barHeight: _number(_theme("geometry.barHeight"), 34)
    readonly property real screenMargin: _number(_theme("geometry.panelGap"), 6)
    readonly property real exclusionZone: barHeight + screenMargin
    readonly property color panelColor: _color("colors.surface.panel", "#1e1e2e")
    readonly property color borderColor: _color("colors.border.normal", "#45475a")
    readonly property color focusColor: _color("colors.border.focus", "#89b4fa")
    readonly property color textColor: _color("colors.text.primary", "#cdd6f4")
    readonly property color mutedTextColor: _color("colors.text.secondary", "#a6adc8")
    readonly property real radius: _number(_theme("geometry.radius"), 8)

    function _theme(path) {
        var value = context && context.theme ? context.theme : {}
        var parts = path.split(".")
        for (var index = 0; index < parts.length; index++) {
            if (value === undefined || value === null)
                return undefined
            value = value[parts[index]]
        }
        return value
    }

    function _number(value, fallback) {
        return typeof value === "number" && isFinite(value) ? value : fallback
    }

    function _color(path, fallback) {
        var value = _theme(path)
        return typeof value === "string" ? value : fallback
    }

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
            readonly property bool focused: root.context
                && root.context.compositor
                && root.context.compositor.focusedOutputId === outputId

            screen: modelData
            visible: true
            anchors {
                top: true
                left: true
                right: true
            }
            margins {
                top: root.screenMargin
                left: root.screenMargin
                right: root.screenMargin
            }
            implicitHeight: root.barHeight
            exclusiveZone: root.shadowMode ? 0 : root.exclusionZone
            color: "transparent"
            WlrLayershell.namespace: "stillsuit.bar"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                radius: root.radius
                color: root.panelColor
                border.width: 1
                border.color: barWindow.focused ? root.focusColor : root.borderColor
                clip: true

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 9
                    spacing: 8

                    RowLayout {
                        id: leftSlot
                        objectName: "stillsuit-bar-left"
                        spacing: 6
                        Layout.alignment: Qt.AlignVCenter
                        Repeater {
                            model: root.recordsFor("left")
                            WidgetSlot {
                                required property var modelData
                                registration: modelData.registration
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        id: centerSlot
                        objectName: "stillsuit-bar-center"
                        spacing: 6
                        Layout.alignment: Qt.AlignVCenter
                        Repeater {
                            model: root.recordsFor("center")
                            WidgetSlot {
                                required property var modelData
                                registration: modelData.registration
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        id: rightSlot
                        objectName: "stillsuit-bar-right"
                        spacing: 6
                        Layout.alignment: Qt.AlignVCenter
                        Repeater {
                            model: root.recordsFor("right")
                            WidgetSlot {
                                required property var modelData
                                registration: modelData.registration
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: centerSlot.children.length === 0
                    text: "Stillsuit"
                    color: root.mutedTextColor
                    font.family: root._theme("typography.family") || "sans-serif"
                    font.pixelSize: Math.max(11, root._number(root._theme("typography.baseSize"), 13))
                }
            }
        }
    }
}
