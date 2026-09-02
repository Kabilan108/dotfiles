import QtQuick
import "../../../ui" as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property var service
    required property string outputId

    readonly property int usedPercent: service && service.maxUsed >= 0
        ? Math.round(service.maxUsed * 100) : -1

    theme: context.theme
    iconName: "agent"
    label: usedPercent >= 0 ? usedPercent + "%" : ""
    active: context.panels.isOpen("stillsuit.agent-usage")
    busy: Boolean(service && service.refreshing)
    accessibleName: !service || !service.available
        ? "Agent usage unavailable"
        : service.accountCount === 0
            ? "No agent accounts configured"
            : usedPercent >= 0
                ? "Agent usage, highest account at " + usedPercent
                    + " percent used across " + service.accountCount + " accounts"
                : "Agent usage for " + service.accountCount + " accounts"
    onClicked: context.actions.surfaceToggle("stillsuit.agent-usage", "")
}
