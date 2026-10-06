import QtQuick
import Stillsuit.Ui as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property var service
    required property string outputId

    readonly property string panelId: "stillsuit.dev-checkouts"
    readonly property bool failing: service.lastError !== "" || !service.available

    theme: context.theme
    iconSource: Qt.resolvedUrl("assets/moberg.svg")
    label: service.loaded ? String(service.runningCount) : ""
    contentColor: failing
        ? context.theme.semantic.status.danger
        : service.runningCount === 0 && !selected ? context.theme.semantic.content.muted
        : selected ? context.theme.component.bar.clusterActiveText
        : context.theme.component.bar.clusterText
    tooltipText: !service.available ? "Dev checkouts: status helper not configured"
        : service.lastError !== "" ? "Dev checkouts: " + service.lastError
        : service.runningCount + " of " + service.checkouts.length + " checkouts running"
    accessibleName: "Dev checkouts, " + service.runningCount + " running"
    selected: context.panels && context.panels.selectedId === panelId
        && context.panels.selectedOutputId === outputId
    onClicked: context.actions.surfaceToggle(panelId, JSON.stringify({ outputId: root.outputId }))
}
