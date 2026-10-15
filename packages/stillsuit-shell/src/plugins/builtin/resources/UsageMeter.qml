pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Stillsuit.Ui as Ui

RowLayout {
    id: root
    required property var theme
    required property var service
    required property string label
    property var percent: null
    property string detail: ""
    // Host cards share these so every bar in the panel starts and ends at the same x.
    property real labelWidth: labelText.implicitWidth
    property real detailWidth: detailText.implicitWidth
    property real percentWidth: percentText.implicitWidth
    readonly property bool available: service.validPercent(percent)
    readonly property color usageColor: available
        ? theme.semantic.intensity[service.usageBand(percent)] : theme.semantic.content.muted
    spacing: theme.metrics.spaceUnit * 2.5
    Accessible.name: label + ", " + service.percent(percent) + (detail ? ", " + detail : "")

    Ui.ShellText {
        id: labelText
        Layout.preferredWidth: root.labelWidth
        theme: root.theme
        text: root.label
        role: "secondary"
        elide: Text.ElideRight
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: root.theme.metrics.spaceUnit * 1.25
        radius: height / 2
        color: root.theme.component.osd.track
        Rectangle {
            height: parent.height
            width: parent.width * (root.available ? root.percent : 0) / 100
            radius: height / 2
            color: root.usageColor
        }
    }
    Ui.ShellText {
        id: detailText
        Layout.preferredWidth: root.detailWidth
        theme: root.theme
        text: root.detail
        sizeRole: "caption"
        role: "muted"
        monospace: true
        horizontalAlignment: Text.AlignRight
    }
    Ui.ShellText {
        id: percentText
        Layout.preferredWidth: root.percentWidth
        theme: root.theme
        text: root.service.percent(root.percent)
        monospace: true
        font.weight: root.theme.typography.weightMedium
        horizontalAlignment: Text.AlignRight
        color: root.usageColor
    }
}
