import QtQuick
import QtQuick.Layouts
import "../ui" as Ui

Ui.ShellSurface {
    id: root

    property real speedScale: 1
    property bool reducedMotion: false
    property bool played: false

    implicitWidth: 440
    implicitHeight: 190
    kind: "raised"

    Ui.ShellText {
        anchors {
            left: parent.left
            top: parent.top
            margins: 14
        }
        theme: root.theme
        text: reducedMotion ? "Reduced motion" : "Panel enter · " + Math.round(theme.motion.normal * speedScale) + " ms"
        sizeRole: "label"
    }

    Rectangle {
        id: card
        width: 210
        height: 78
        radius: root.theme.metrics.radiusMedium
        color: root.theme.component.panel.background
        border.width: 1
        border.color: root.theme.component.panel.border
        x: root.played || root.reducedMotion ? 18 : 18 + root.theme.motion.distanceMedium
        y: 58
        opacity: root.played || root.reducedMotion ? 1 : 0.25

        Behavior on x {
            NumberAnimation {
                duration: root.reducedMotion ? 0 : Math.round(root.theme.motion.normal * root.speedScale)
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.reducedMotion ? 0 : Math.round(root.theme.motion.normal * root.speedScale)
                easing.type: Easing.OutCubic
            }
        }

        RowLayout {
            anchors {
                fill: parent
                margins: 12
            }

            Ui.ShellIcon {
                theme: root.theme
                name: "success"
                sizeRole: "large"
                color: root.theme.semantic.status.success
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Ui.ShellText {
                    theme: root.theme
                    text: "Connection restored"
                    sizeRole: "label"
                }

                Ui.ShellText {
                    theme: root.theme
                    text: "Motion explains the change."
                    role: "muted"
                    sizeRole: "caption"
                }
            }
        }
    }

    RowLayout {
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 14
        }
        spacing: 8

        Ui.ShellButton {
            theme: root.theme
            label: "Reset"
            compact: true
            onClicked: root.played = false
        }

        Ui.ShellButton {
            theme: root.theme
            label: "Play"
            iconName: "play"
            compact: true
            active: true
            onClicked: {
                root.played = false
                Qt.callLater(function() {
                    root.played = true
                })
            }
        }
    }
}
