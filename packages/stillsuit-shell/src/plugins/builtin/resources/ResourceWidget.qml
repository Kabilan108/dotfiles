import QtQuick
import "../../../ui" as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property var service
    required property string outputId

    theme: context.theme
    iconName: "cpu"
    label: _percent(service ? service.cpuPercent : null)
        + "  " + _percent(service ? service.memoryPercent : null)
    accessibleName: "CPU " + _percent(service ? service.cpuPercent : null)
        + ", memory " + _percent(service ? service.memoryPercent : null)
    active: context.panels && context.panels.isOpen("stillsuit.resources")
    enabled: service !== null
    onClicked: context.actions.surfaceToggle("stillsuit.resources", "")

    function _percent(value) {
        if (value === undefined || value === null || value === "")
            return "--"
        return Math.round(Number(value)) + "%"
    }
}
