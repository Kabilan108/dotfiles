// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts

ShellAction {
    id: root
    required property var theme
    property string iconName: "settings"
    property url iconSource: ""
    // A second icon beside the first, by catalog name or image source.
    property string secondaryIconName: ""
    property url secondaryIconSource: ""
    // A small overlay on the corner of the first icon.
    property string badgeIconName: ""
    property string label: ""
    property string secondaryLabel: ""
    property bool selected: false
    property bool reducedMotion: false
    property string tooltipText: effectiveAccessibleName
    property color contentColor: selected
        ? theme.component.bar.clusterActiveText : theme.component.bar.clusterText
    readonly property int motionDuration: reducedMotion ? 0 : theme.motion.fast
    signal clicked()
    accessibleFallback: label !== "" ? label : iconName.replace(/-/g, " ")
    implicitWidth: Math.max(24, clusterRow.implicitWidth + 14)
    implicitHeight: Math.max(22, theme.metrics.barHeight - 6)
    onActivated: clicked()

    Rectangle {
        anchors.fill: parent
        radius: root.theme.metrics.radiusSmall
        color: root.selected ? root.theme.component.bar.clusterActive
            : root.pressed ? root.theme.semantic.surface.pressed
            : root.hovered ? root.theme.component.bar.clusterHover : "transparent"
        opacity: !root.enabled ? 0.74 : root.busy ? 0.82 : 1
        Behavior on color {
            ColorAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic }
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
            color: root.contentColor
        }
        ShellIcon {
            visible: !root.busy
            theme: root.theme
            source: root.iconSource
            name: root.iconName
            sizeRole: "small"
            color: root.contentColor
            Layout.preferredWidth: root.theme.metrics.iconSmall
            Layout.preferredHeight: root.theme.metrics.iconSmall
            ShellIcon {
                visible: root.badgeIconName !== ""
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -4
                anchors.bottomMargin: -3
                theme: root.theme
                name: root.badgeIconName
                sizeRole: "small"
                scale: 0.56
                color: root.contentColor
            }
        }
        ShellText {
            visible: root.label !== ""
            theme: root.theme
            text: root.label
            sizeRole: "caption"
            monospace: true
            color: root.contentColor
        }
        ShellIcon {
            visible: root.secondaryIconName !== "" || String(root.secondaryIconSource) !== ""
            Layout.leftMargin: 3
            Layout.preferredWidth: root.theme.metrics.iconSmall
            Layout.preferredHeight: root.theme.metrics.iconSmall
            theme: root.theme
            name: root.secondaryIconName !== "" ? root.secondaryIconName : "circle"
            source: root.secondaryIconSource
            sizeRole: "small"
            color: root.contentColor
        }
        ShellText {
            visible: root.secondaryLabel !== ""
            theme: root.theme
            text: root.secondaryLabel
            sizeRole: "caption"
            monospace: true
            color: root.contentColor
        }
    }
}
