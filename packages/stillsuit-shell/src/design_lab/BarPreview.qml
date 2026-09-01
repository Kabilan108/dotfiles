import QtQuick
import QtQuick.Layouts
import "../ui" as Ui

Rectangle {
    id: root

    required property var theme
    property bool anchored: true
    property string label: "2256 px output"

    implicitWidth: 980
    implicitHeight: 146
    radius: theme.metrics.radiusMedium
    clip: true
    color: theme.semantic.background.desktop

    gradient: Gradient {
        GradientStop {
            position: 0
            color: root.theme.palette.chromatic.blue || root.theme.semantic.status.info
        }
        GradientStop {
            position: 0.44
            color: root.theme.semantic.background.desktop
        }
        GradientStop {
            position: 1
            color: root.theme.palette.chromatic.red || root.theme.semantic.status.danger
        }
    }

    Ui.ShellText {
        anchors {
            left: parent.left
            bottom: parent.bottom
            margins: 10
        }
        theme: root.theme
        text: root.label + "  ·  " + root.theme.metrics.barHeight + "px  ·  " + (root.anchored ? "anchored" : "floating")
        sizeRole: "caption"
        role: "muted"
        monospace: true
    }

    Ui.ShellSurface {
        id: bar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: root.anchored ? 0 : root.theme.metrics.barOuterGap
            leftMargin: root.anchored ? 0 : root.theme.metrics.barOuterGap
            rightMargin: root.anchored ? 0 : root.theme.metrics.barOuterGap
        }
        height: root.theme.metrics.barHeight
        theme: root.theme
        kind: "bar"
        radius: root.anchored ? 0 : root.theme.metrics.radiusMedium

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 8
                rightMargin: 8
            }
            spacing: root.theme.metrics.barInnerGap

            RowLayout {
                spacing: 5

                Repeater {
                    model: 5

                    Rectangle {
                        required property int index
                        Layout.preferredWidth: index === 1 ? 17 : 7
                        Layout.preferredHeight: 6
                        radius: 3
                        color: index === 1
                            ? root.theme.component.bar.workspaceActive
                            : root.theme.component.bar.workspaceIdle
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: Math.max(12, root.theme.metrics.barHeight - 14)
                    color: root.theme.component.bar.separator
                }

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index
                        Layout.preferredWidth: index === 2 ? 9 : 4
                        Layout.preferredHeight: 9
                        radius: 2
                        color: index === 2
                            ? root.theme.component.bar.workspaceActive
                            : root.theme.component.bar.workspaceIdle
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Ui.ShellText {
                theme: root.theme
                text: "MON 31 AUG  ·  22:14"
                sizeRole: "caption"
                monospace: true
                role: "secondary"
            }

            Item {
                Layout.fillWidth: true
            }

            Ui.ShellBarCluster {
                theme: root.theme
                iconName: "cpu"
                label: "18%  42%"
            }

            Ui.ShellBarCluster {
                theme: root.theme
                iconName: "network"
            }

            Ui.ShellBarCluster {
                theme: root.theme
                iconName: "bluetooth"
            }

            Ui.ShellBarCluster {
                theme: root.theme
                iconName: "audio"
                label: "34"
                active: true
            }

            Ui.ShellBarCluster {
                theme: root.theme
                iconName: "notifications"
            }

            Ui.ShellBarCluster {
                theme: root.theme
                iconName: "battery"
                label: "78"
            }
        }
    }
}
