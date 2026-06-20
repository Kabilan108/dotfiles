import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool active: false
    property bool enabled: false
    property bool alert: false
    property bool compact: false
    property bool highlightLabel: false
    property bool emphasizeState: false
    property bool clickable: true
    property color accentColor: alert ? Theme.urgent : Theme.accent
    readonly property color textColor: alert ? Theme.urgent
        : emphasizeState ? accentColor
        : Theme.accent2
    readonly property color chromeColor: alert ? Theme.urgent
        : active ? accentColor
        : Theme.panelBorder

    signal clicked()

    implicitWidth: Math.max(28, row.implicitWidth + (compact ? 10 : 14))
    implicitHeight: 28
    radius: Theme.radiusSmall
    color: active || alert ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18)
        : mouse.containsMouse ? Theme.panelSurfaceHover
        : "transparent"
    border.width: active || alert || mouse.containsMouse ? Theme.borderWidth : 0
    border.color: active || alert ? chromeColor : Theme.panelBorder

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: root.icon !== ""
            text: root.icon
            color: root.textColor
            font.family: Theme.iconFamily
            font.pixelSize: compact ? 16 : 18
            font.variableAxes: ({ "FILL": root.alert || root.emphasizeState ? 1 : 0, "wght": 500, "opsz": 20 })
            verticalAlignment: Text.AlignVCenter
        }

        Rectangle {
            visible: root.label !== ""
            radius: root.highlightLabel ? Math.floor(height / 2) : 0
            color: root.highlightLabel ? Theme.accent : "transparent"
            border.width: 0
            border.color: "transparent"
            implicitWidth: root.highlightLabel
                ? Math.max(labelText.implicitWidth + 8, labelText.implicitHeight + 2)
                : labelText.implicitWidth
            implicitHeight: labelText.implicitHeight + (root.highlightLabel ? 2 : 0)

            Text {
                id: labelText
                anchors.centerIn: parent
                text: root.label
                color: root.highlightLabel ? Theme.base_
                    : root.textColor
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: root.highlightLabel
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
