import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property string icon
    required property real value
    required property color accentColor
    property string label: ""
    readonly property int visualWidth: Math.max(Theme.osdWidth, 360)
    readonly property int visualHeight: Math.max(Theme.osdHeight, 58)
    readonly property color surfaceColor: Theme.panelSurface

    implicitWidth: visualWidth
    implicitHeight: visualHeight
    radius: Theme.radiusLarge
    color: Theme.panelBgStrong
    border.width: Math.max(1, Theme.borderWidth * 2)
    border.color: Theme.panelBorderStrong
    clip: true

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.border.width
        radius: Math.max(0, root.radius - root.border.width)
        color: "transparent"
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
            }
            GradientStop {
                position: 0.36
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Qt.rgba(root.surfaceColor.r, root.surfaceColor.g, root.surfaceColor.b, 0.12)
            }
        }
    }

    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: 3
        color: root.accentColor
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 14
            rightMargin: 16
        }
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: Theme.radiusMedium
            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
            border.width: Theme.borderWidth
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.accentColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeIconLarge
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.label
                    color: Theme.text
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 8
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
}
