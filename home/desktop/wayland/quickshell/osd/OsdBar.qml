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
    radius: height / 2
    color: "#e0181825"

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
            font.family: "FiraMono Nerd Font"
            font.pixelSize: 20
            Layout.preferredWidth: 24
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: "#30cdd6f4"

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
            color: "#cdd6f4"
            font.family: "FiraMono Nerd Font"
            font.pixelSize: 12
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
        }
    }
}
