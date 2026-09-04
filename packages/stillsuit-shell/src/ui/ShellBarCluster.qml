// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Layouts

ShellAction {
    id: root

    required property var theme
    property string iconName: "settings"
    property url iconSource: ""
    property url secondaryIconSource: ""
    property string badgeIconName: ""
    property string label: ""
    property bool active: false
    property bool reducedMotion: false

    readonly property int motionDuration: reducedMotion ? 0 : theme.motion.fast

    signal clicked()

    accessibleFallback: label !== "" ? label : iconName.replace(/-/g, " ")
    implicitWidth: Math.max(24, clusterRow.implicitWidth + 14)
    implicitHeight: Math.max(22, theme.metrics.barHeight - 6)
    onActivated: clicked()

    Rectangle {
        anchors.fill: parent
        radius: root.theme.metrics.radiusSmall
        color: root.active
            ? root.theme.component.bar.clusterActive
            : root.pressed
                ? root.theme.semantic.surface.pressed
                : root.hovered
                    ? root.theme.component.bar.clusterHover
                    : "transparent"
        border.width: 0
        opacity: !root.enabled ? 0.74 : root.busy ? 0.82 : 1

        Behavior on color {
            ColorAnimation {
                duration: root.motionDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    RowLayout {
        id: clusterRow

        anchors.centerIn: parent
        spacing: 5

        ShellBusyIndicator {
            visible: root.busy
            theme: root.theme
            reducedMotion: root.reducedMotion
            sizeRole: "small"
            color: root.active
                ? root.theme.component.bar.clusterActiveText
                : root.theme.component.bar.clusterText
        }

        Item {
            visible: !root.busy
            Layout.preferredWidth: root.theme.metrics.iconSmall
                + (String(root.secondaryIconSource) !== ""
                    ? root.theme.metrics.iconSmall + 3 : 0)
            Layout.preferredHeight: root.theme.metrics.iconSmall

            Row {
                anchors.centerIn: parent
                spacing: 3

                Item {
                    width: root.theme.metrics.iconSmall
                    height: root.theme.metrics.iconSmall

                    Image {
                        visible: String(root.iconSource) !== ""
                        anchors.fill: parent
                        source: root.iconSource
                        sourceSize.width: width
                        sourceSize.height: height
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                    }

                    ShellIcon {
                        visible: String(root.iconSource) === ""
                        anchors.centerIn: parent
                        theme: root.theme
                        name: root.iconName
                        sizeRole: "small"
                        color: root.active
                            ? root.theme.component.bar.clusterActiveText
                            : root.theme.component.bar.clusterText
                    }
                }

                Item {
                    visible: String(root.secondaryIconSource) !== ""
                    width: visible ? root.theme.metrics.iconSmall : 0
                    height: root.theme.metrics.iconSmall

                    Image {
                        anchors.fill: parent
                        source: root.secondaryIconSource
                        sourceSize.width: width
                        sourceSize.height: height
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                    }
                }
            }

            ShellIcon {
                visible: root.badgeIconName !== ""
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: -4
                    bottomMargin: -3
                }
                theme: root.theme
                name: root.badgeIconName
                sizeRole: "small"
                scale: 0.56
                color: root.active
                    ? root.theme.component.bar.clusterActiveText
                    : root.theme.component.bar.clusterText
            }
        }

        ShellText {
            visible: root.label !== ""
            theme: root.theme
            text: root.label
            sizeRole: "caption"
            monospace: true
            color: root.active
                ? root.theme.component.bar.clusterActiveText
                : root.theme.component.bar.clusterText
        }
    }
}
