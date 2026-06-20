import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property string icon
    required property real value
    required property color accentColor
    property string label: ""
    readonly property int visualWidth: 300
    readonly property int visualHeight: 40

    implicitWidth: visualWidth
    implicitHeight: visualHeight
    radius: Theme.radiusPill
    color: Theme.panelBgStrong
    border.width: Theme.borderWidth
    border.color: Theme.panelBorder
    clip: true

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 18
            rightMargin: 18
        }
        spacing: 13

        Text {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter

            text: root.icon
            color: root.accentColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: Theme.iconFamily
            font.variableAxes: ({ "FILL": 0, "wght": 500, "opsz": 20 })
            font.pixelSize: 17
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
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
    }
}
