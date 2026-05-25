import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property string icon
    required property real value
    required property color accentColor
    property string label: ""

    implicitWidth: Theme.osdWidth
    implicitHeight: Theme.osdHeight
    radius: Theme.radiusPill
    color: Theme.panelBgStrong
    border.width: Theme.borderWidth
    border.color: Theme.panelBorder

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 18
            rightMargin: 18
        }
        spacing: 14

        Text {
            text: root.icon
            color: root.accentColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeIconLarge
            Layout.preferredWidth: 28
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 7
            radius: Theme.radiusPill
            color: Theme.osdTrack

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
                    NumberAnimation {
                        duration: Theme.animationMedium
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Text {
            text: root.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            Layout.preferredWidth: 42
            horizontalAlignment: Text.AlignRight
        }
    }
}
