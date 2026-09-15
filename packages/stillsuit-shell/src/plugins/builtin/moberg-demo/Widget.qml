import QtQuick
import Stillsuit.Ui as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property string outputId

    readonly property string configuredLabel: String(
        context.settings.values.label || "Moberg demo")

    theme: context.theme
    iconName: "agent"
    label: configuredLabel
    accessibleName: configuredLabel + " on " + outputId
    onClicked: context.logger.info("Moberg profile demo clicked on " + outputId)
}
