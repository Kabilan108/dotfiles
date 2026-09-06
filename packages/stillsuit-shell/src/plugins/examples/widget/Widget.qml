import QtQuick
import Stillsuit.Ui as Ui

// A bar widget receives the host context and the output it is drawn on.
// It renders state; it never owns timers, sockets, or processes.
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
