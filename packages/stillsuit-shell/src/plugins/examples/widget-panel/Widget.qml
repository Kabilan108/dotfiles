import QtQuick
import Stillsuit.Ui as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property string outputId

    theme: context.theme
    iconName: "info"
    label: "panel"
    accessibleName: "Open the example panel"
    // `selected` highlights the chip only while this output shows the panel.
    selected: context.panels && context.panels.selectedId === "stillsuit.example-panel"
        && context.panels.selectedOutputId === outputId
    onClicked: context.actions.surfaceToggle("stillsuit.example-panel",
        JSON.stringify({ outputId: root.outputId }))
}
