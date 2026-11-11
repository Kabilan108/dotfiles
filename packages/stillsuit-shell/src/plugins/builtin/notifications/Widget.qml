import QtQuick
import "../../../ui" as Ui

// The bell toggles quiet mode. While quiet, it shows how many notifications
// will replay when quiet ends.
Ui.ShellBarCluster {
    id: root

    required property var context
    required property var service
    required property string outputId

    readonly property bool quiet: service ? service.quietActive : false
    readonly property int heldCount: service ? service.heldCount : 0

    theme: context.theme
    iconName: quiet ? "notifications-off" : "notifications"
    label: service ? service.heldBadgeText : ""
    contentColor: quiet ? theme.semantic.status.warning : theme.component.bar.clusterText
    accessibleName: !quiet ? "Notifications on. Activate to turn on quiet mode" : heldCount === 0
                             ? "Quiet mode on. Activate to turn it off" : "Quiet mode on, " + String(
                                   heldCount) + " held. Activate to turn it off and show them"
    tooltipText: !quiet ? "Quiet mode off" : heldCount === 0 ? "Quiet mode on" : "Quiet mode on · "
                                                               + String(heldCount) + " held"
    onClicked: if (service)
                   service.toggleQuiet()
}
