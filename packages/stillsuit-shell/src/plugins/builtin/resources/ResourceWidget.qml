import QtQuick
import "../../../ui" as Ui

Item {
    id: root

    required property var context
    required property var service
    required property string outputId

    readonly property string accessibleName: "CPU " + _percent(service ? service.cpuPercent : null)
        + ", memory " + _percent(service ? service.memoryPercent : null)
    implicitWidth: Math.max(24, metrics.implicitWidth + 14)
    implicitHeight: Math.max(22, context.theme.metrics.barHeight - 6)

    Ui.ShellText {
        id: metrics

        anchors.centerIn: parent
        theme: root.context.theme
        text: "CPU: " + root._percent(root.service ? root.service.cpuPercent : null)
            + "  MEM: " + root._percent(root.service ? root.service.memoryPercent : null)
        sizeRole: "caption"
        monospace: true
        role: "secondary"
    }

    function _percent(value) {
        if (value === undefined || value === null || value === "")
            return "--"
        return Math.round(Number(value)) + "%"
    }
}
