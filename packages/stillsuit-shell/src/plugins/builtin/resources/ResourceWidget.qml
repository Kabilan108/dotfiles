import QtQuick
import QtQuick.Layouts
import "../../../ui" as Ui

Item {
    id: root

    required property var context
    required property var service
    required property string outputId

    readonly property string accessibleName: "CPU " + _percent(service ? service.cpuPercent : null)
        + ", memory " + _percent(service ? service.memoryPercent : null)
    implicitWidth: metrics.implicitWidth
    implicitHeight: context.theme.metrics.barHeight

    RowLayout {
        id: metrics

        anchors.centerIn: parent
        spacing: 5

        Ui.ShellIcon {
            theme: root.context.theme
            name: "memory"
            sizeRole: "small"
            role: "secondary"
        }

        Ui.ShellText {
            theme: root.context.theme
            text: root._percent(root.service ? root.service.memoryPercent : null)
            sizeRole: "caption"
            monospace: true
            role: "secondary"
        }
    }

    function _percent(value) {
        if (value === undefined || value === null || value === "")
            return "--"
        return Math.round(Number(value)) + "%"
    }
}
