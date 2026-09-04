import QtQuick
import "../../../ui" as Ui

Item {
    id: root

    required property var context
    required property var service
    required property string outputId

    readonly property string accessibleName: "CPU " + _percent(service ? service.cpuPercent : null)
        + ", memory " + _percent(service ? service.memoryPercent : null)
    readonly property color cpuColor: _usageColor(service ? service.cpuPercent : null)
    readonly property color memoryColor: _usageColor(service ? service.memoryPercent : null)
    implicitWidth: Math.max(24, metrics.implicitWidth + 14)
    implicitHeight: Math.max(22, context.theme.metrics.barHeight - 6)

    Row {
        id: metrics

        anchors.centerIn: parent
        spacing: root.context.theme.metrics.spaceUnit * 2

        Row {
            spacing: root.context.theme.metrics.spaceUnit

            Ui.ShellText {
                theme: root.context.theme
                text: "CPU:"
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
            spacing: root.context.theme.metrics.spaceUnit

            Ui.ShellText {
                theme: root.context.theme
                text: "MEM:"
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
        var colors = context.theme.component.resources
        return band !== "" && colors && colors[band] !== undefined
            ? colors[band] : context.theme.semantic.content.secondary
    }
}
