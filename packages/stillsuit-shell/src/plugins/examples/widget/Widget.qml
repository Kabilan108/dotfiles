import QtQuick
import Stillsuit.Ui as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property string outputId

    theme: context.theme
    iconName: "agent"
    label: "hello"
    accessibleName: "Example widget on " + outputId
    onClicked: context.logger.info("example widget clicked on " + outputId)
}
