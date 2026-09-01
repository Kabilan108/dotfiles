import QtQuick
import "../../../ui" as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property var service
    required property string outputId

    readonly property string displayIconName: _iconName()

    theme: context.theme
    iconName: displayIconName
    label: service && service.available ? service.percentage + "%" : "--"
    accessibleName: service && service.available
        ? "Battery " + service.percentage + " percent, " + service.stateLabel
        : "Battery unavailable"
    active: context.panels && context.panels.isOpen("stillsuit.battery")
    enabled: service && service.available
    visible: service && service.present
    onClicked: context.actions.surfaceToggle("stillsuit.battery", "")

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
}
