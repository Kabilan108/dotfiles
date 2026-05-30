import QtQuick
import Quickshell.Services.Notifications

Item {
    id: root

    required property Notification notification
    property bool inline: false

    signal dismissed()

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    NotificationCard {
        id: card
        anchors.fill: parent
        notification: root.notification
        inline: root.inline
        onDismissed: root.dismissed()
    }
}
