import QtQuick
import Stillsuit.Ui as Ui

Item {
    id: root

    required property var context
    required property var service
    required property string outputId

    readonly property string accessibleName: "CPU " + _percent(service ? service.cpuPercent : null)
        + ", memory " + _percent(service ? service.memoryPercent : null)
    readonly property string panelId: "stillsuit.resources"
    readonly property bool selected: context.panels && context.panels.selectedId === panelId
        && context.panels.selectedOutputId === outputId
    // This plugin draws a two-row tooltip; the bar's text-only tooltip stays empty.
    property string tooltipText: ""
    readonly property string cpuLabel: "CPU:"
    readonly property string memoryLabel: "MEM:"
    readonly property color cpuColor: _usageColor(service ? service.cpuPercent : null)
    readonly property color memoryColor: _usageColor(service ? service.memoryPercent : null)
    implicitWidth: Math.max(24, metrics.implicitWidth + 14)
    implicitHeight: Math.max(22, context.theme.metrics.barHeight - 6)

    HoverHandler {
        onHoveredChanged: {
            if (root.service && typeof root.service.setHovered === "function")
                root.service.setHovered(root.outputId, hovered)
        }
    }

    Component.onDestruction: {
        if (service && typeof service.setHovered === "function")
            service.setHovered(outputId, false)
    }

    ResourceTooltip {
        theme: root.context.theme
        service: root.service
        target: root
        showing: root.service && root.service.tooltipOutputId === root.outputId && !root.selected
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.context.actions.surfaceToggle(root.panelId, JSON.stringify({ outputId: root.outputId }))
    }

    Row {
        id: metrics

        anchors.centerIn: parent
        spacing: root.context.theme.metrics.spaceUnit * 3

        Row {
            spacing: root.context.theme.metrics.spaceUnit / 2

            Ui.ShellText {
                theme: root.context.theme
                text: root.cpuLabel
                sizeRole: "caption"
                monospace: true
                role: "secondary"
            }

            Ui.ShellText {
                theme: root.context.theme
                text: root._percent(root.service ? root.service.cpuPercent : null)
                sizeRole: "caption"
                monospace: true
                color: root.cpuColor
            }
        }

        Row {
            spacing: root.context.theme.metrics.spaceUnit / 2

            Ui.ShellText {
                theme: root.context.theme
                text: root.memoryLabel
                sizeRole: "caption"
                monospace: true
                role: "secondary"
            }

            Ui.ShellText {
                theme: root.context.theme
                text: root._percent(root.service ? root.service.memoryPercent : null)
                sizeRole: "caption"
                monospace: true
                color: root.memoryColor
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
        var colors = context.theme.semantic.intensity
        return band !== "" && colors && colors[band] !== undefined
            ? colors[band] : context.theme.semantic.content.secondary
    }
}
