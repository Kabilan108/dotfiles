import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property string icon
    required property real value
    required property color accentColor
    property string label: ""

    implicitWidth: 280
    implicitHeight: 44
    radius: Theme.radiusPill
    color: Theme.panelBg

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 16
            rightMargin: 16
        }
        spacing: 12

        Text {
            text: root.icon
            color: root.accentColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeIcon
            Layout.preferredWidth: 24
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: "#1fcdd6f4"

            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: parent.width * Math.min(Math.max(root.value, 0), 1)
                radius: parent.radius
                color: root.accentColor

                Behavior on width {
                    SmoothedAnimation { velocity: 600 }
                }
            }
        }

        Text {
            text: root.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
        }
    }
}
