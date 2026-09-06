import QtQuick
import Stillsuit.Ui as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property string outputId

    theme: context.theme
    iconName: "brightness"
    label: "icons"
    accessibleName: "Open icon gallery"
    selected: context.panels && context.panels.selectedId === "stillsuit.icon-gallery"
        && context.panels.selectedOutputId === outputId
    onClicked: context.actions.surfaceToggle("stillsuit.icon-gallery", JSON.stringify({outputId: root.outputId}))
}
