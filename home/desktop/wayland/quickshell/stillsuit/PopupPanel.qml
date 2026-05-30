import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    default property alias content: contentLayout.children

    property int padding: Theme.paddingMedium
    readonly property color accentColor: Theme.accent
    readonly property color surfaceColor: Theme.panelSurface

    implicitWidth: 320
    implicitHeight: contentLayout.implicitHeight + padding * 2
    radius: Theme.radiusLarge
    color: Theme.panelBgStrong
    border.width: Math.max(1, Theme.borderWidth * 2)
    border.color: Theme.panelBorderStrong
    clip: true

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: 2
        color: Theme.accent
        opacity: 0.8
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.border.width
        radius: Math.max(0, root.radius - root.border.width)
        color: "transparent"
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.08)
            }
            GradientStop {
                position: 0.45
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Qt.rgba(root.surfaceColor.r, root.surfaceColor.g, root.surfaceColor.b, 0.16)
            }
        }
    }

    ColumnLayout {
        id: contentLayout
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: Theme.panelGap
    }
}
