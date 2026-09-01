import QtQuick
import "../../../ui" as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property var service
    required property string outputId

    theme: context.theme
    iconName: "battery"
    label: service && service.available ? service.percentage + "%" : "--"
    accessibleName: service && service.available
        ? "Battery " + service.percentage + " percent, " + service.stateLabel
        : "Battery unavailable"
    active: context.panels && context.panels.isOpen("stillsuit.battery")
    enabled: service && service.available
    visible: service && service.present
    onClicked: context.actions.surfaceToggle("stillsuit.battery", "")
}
