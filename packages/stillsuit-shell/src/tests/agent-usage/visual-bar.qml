import QtQuick
import Quickshell
import "../../plugins/builtin/agent-usage" as AgentUsage

PanelWindow {
    id: root

    required property var context
    required property var service

    color: root.context.theme.component.bar.background
    implicitWidth: visualWidget.implicitWidth + 8
    implicitHeight: root.context.theme.metrics.barHeight
    anchors {
        top: true
        right: true
    }

    AgentUsage.Widget {
        id: visualWidget

        anchors.centerIn: parent
        context: root.context
        service: root.service
        outputId: "fixture-output"
    }
}
