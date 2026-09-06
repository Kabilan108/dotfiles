import QtQuick
import QtQuick.Layouts
import "../ui" as Ui
import "../plugins/builtin/workspaces" as Workspaces

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
        bordered: false
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.theme.component.bar.border
        }
        Ui.ShellText {
            anchors.centerIn: parent
            theme: root.theme
            text: "05-09-2026  22:14:32"
            monospace: true
            sizeRole: "caption"
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 8
                rightMargin: 8
            }
            spacing: root.theme.metrics.barInnerGap

            Workspaces.WorkspaceWidget {
                outputId: "lab"
                context: ({
                    theme: root.theme,
                    settings: {values: {}},
                    compositor: {
                        workspaces: [
                            { id: 1, idx: 1, output: "lab", is_active: true, is_urgent: false },
                            { id: 2, idx: 2, output: "lab", is_active: false, is_urgent: false }
                        ],
                        windows: []
                    }
                })
            }

            Item {
                Layout.fillWidth: true
            }


            Item {
                Layout.fillWidth: true
            }

            Ui.ShellText {
                theme: root.theme
                text: "CPU: 18%  MEM: 42%"
                monospace: true
                sizeRole: "caption"
                color: root.theme.semantic.intensity.normal
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
                label: "34%"
                selected: true
            }

            Ui.ShellBarCluster {
                theme: root.theme
                iconName: "notifications"
            }

            Ui.ShellBarCluster {
                theme: root.theme
                iconName: "battery"
                label: "78%"
            }
        }
    }
}
