import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var theme
    property string label: "Value"
    property real value: 0.5
    property real from: 0
    property real to: 1
    property int decimals: 0
    property string suffix: ""

    signal moved(real value)

    implicitWidth: 280
    implicitHeight: 44

    RowLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        ShellText {
            theme: root.theme
            text: root.label
            sizeRole: "caption"
            role: "secondary"
        }

        Item {
            Layout.fillWidth: true
        }

        ShellText {
            theme: root.theme
            text: Number(root.value).toFixed(root.decimals) + root.suffix
            sizeRole: "caption"
            monospace: true
        }
    }

    Rectangle {
        id: track
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            bottomMargin: 5
        }
        height: 5
        radius: 3
        color: root.theme.component.osd.track

        Rectangle {
            width: Math.max(0, Math.min(parent.width, parent.width * root._position()))
            height: parent.height
            radius: parent.radius
            color: root.theme.component.osd.fill
        }

        Rectangle {
            x: Math.max(0, Math.min(parent.width - width, parent.width * root._position() - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: 7
            color: root.theme.semantic.content.primary
            border.width: 2
            border.color: root.theme.component.osd.fill
        }

        MouseArea {
            anchors {
                fill: parent
                topMargin: -10
                bottomMargin: -10
            }
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => root._setFromX(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    root._setFromX(mouse.x)
            }
        }
    }

    function _position() {
        return (value - from) / Math.max(0.0001, to - from)
    }

    function _setFromX(x) {
        value = from + Math.max(0, Math.min(1, x / Math.max(1, track.width))) * (to - from)
        moved(value)
    }
}
