import QtQuick
import "../../../ui" as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property var service
    required property string outputId

    theme: context.theme
    iconName: "notifications"
    label: service ? service.unreadBadgeText : ""
    active: service && service.centerOutputId === outputId
    accessibleName: !service || service.unreadCount === 0
        ? "Notifications, no unread items"
        : "Notifications, " + String(service.unreadCount) + " unread items"
    onClicked: context.actions.surfaceToggle("stillsuit.notifications", "")
}
