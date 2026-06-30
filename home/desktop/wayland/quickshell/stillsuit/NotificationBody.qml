import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

ColumnLayout {
    id: bodyRoot

    required property var target

    spacing: 2

    RowLayout {
        Layout.fillWidth: true
        spacing: 5

        Rectangle {
            implicitWidth: 5
            implicitHeight: 5
            radius: 3
            color: bodyRoot.target.accentColor
        }

        Text {
            text: bodyRoot.target.notification.appName || "Notification"
            color: Theme.textTertiary
            font.family: Theme.fontFamily
            font.pixelSize: 9
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Text {
            text: Theme.icon.close
            color: closeMouse.containsMouse ? Theme.textPrimary : Theme.textTertiary
            font.family: Theme.iconFamily
            font.variableAxes: ({ "wght": 500, "opsz": 20 })
            font.pixelSize: 12

            MouseArea {
                id: closeMouse
                anchors {
                    fill: parent
                    margins: -6
                }
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    bodyRoot.target.notification.dismiss()
                    bodyRoot.target.dismissed()
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Image {
            source: {
                if (bodyRoot.target.notification.image) return bodyRoot.target.notification.image
                const icon = bodyRoot.target.notification.appIcon
                if (!icon || icon === "") return ""
                if (icon.startsWith("/")) return "file://" + icon
                return Quickshell.iconPath(icon, true)
            }
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignTop
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
            sourceSize.width: 36
            sourceSize.height: 36
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: bodyRoot.target.notification.summary
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: bodyRoot.target.notification.body
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                visible: text !== ""
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: bodyRoot.target.notification.actions.length > 0

        Repeater {
            model: bodyRoot.target.notification.actions

            Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 24
                radius: Theme.radiusSmall
                color: actionMouse.containsMouse ? Theme.panelSurfaceHover : Theme.panelSurface
                border.width: 1
                border.color: actionMouse.containsMouse ? Theme.panelBorderStrong : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: modelData.text
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: modelData.invoke()
                }
            }
        }
    }
}
