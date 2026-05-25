import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root

    required property Notification notification
    signal dismissed()

    property bool isCritical: root.notification.urgency === NotificationUrgency.Critical
    property bool isLow: root.notification.urgency === NotificationUrgency.Low
    property string accentColor: root.isCritical ? Theme.urgent
                                : root.isLow ? Theme.mutedText
                                : Theme.accent
    property bool inline: false

    implicitWidth: inline ? Theme.panelWidth : 360
    implicitHeight: inline ? inlineContent.implicitHeight : body.implicitHeight

    Rectangle {
        id: accentBar
        visible: !root.inline
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: 3
        color: root.accentColor
        radius: 1

        Rectangle {
            visible: root.isCritical
            anchors.fill: parent
            anchors.margins: -2
            color: "transparent"
            border.width: 2
            border.color: Qt.rgba(1, 0.3, 0.3, 0.12)
            radius: 1
        }
    }

    Rectangle {
        id: body
        visible: !root.inline
        anchors {
            left: accentBar.right
            right: parent.right
            top: parent.top
        }
        implicitHeight: toastContent.implicitHeight + 10 * 2
        color: Theme.panelBgStrong
        border.width: Theme.borderWidth
        border.color: root.isCritical ? Theme.urgent : Theme.panelBorderStrong

        radius: Theme.radiusMedium
        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: Theme.radiusMedium
            color: parent.color
            border.width: parent.border.width
            border.color: parent.border.color
            Rectangle {
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                    topMargin: parent.border.width
                    bottomMargin: parent.border.width
                }
                width: 2
                color: body.color
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animationFast
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: toastContent
            anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 10
                topMargin: 10
                bottomMargin: 10
            }
            spacing: 2

            NotificationBody { target: root }
        }
    }

    RowLayout {
        id: inlineContent
        visible: root.inline
        anchors {
            left: parent.left
            right: parent.right
        }
        spacing: 0

        Rectangle {
            implicitWidth: 3
            Layout.fillHeight: true
            color: root.accentColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 4
            Layout.topMargin: 8
            Layout.bottomMargin: 8
            spacing: 2

            NotificationBody { target: root }
        }
    }
}
