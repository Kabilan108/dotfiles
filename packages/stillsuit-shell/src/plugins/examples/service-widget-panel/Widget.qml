import QtQuick
import Stillsuit.Ui as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property var service
    required property string outputId

    theme: context.theme
    iconName: "refresh"
    label: String(service.count)
    tooltipText: "Ticking for " + service.ticks + "s"
    accessibleName: "Counter at " + service.count
    selected: context.panels && context.panels.selectedId === "stillsuit.example-counter"
        && context.panels.selectedOutputId === outputId
    onClicked: context.actions.surfaceToggle("stillsuit.example-counter",
        JSON.stringify({ outputId: root.outputId }))
}
