import QtQuick
import "../../../ui" as Ui

Item {
    id: root

    required property var context
    required property var service
    required property string outputId

    readonly property string displayText: Qt.formatDateTime(service.now, "MM-dd-yyyy  HH:mm:ss")
    readonly property string accessibleName: "Clock on " + outputId + ": " + displayText

    implicitWidth: label.implicitWidth + context.theme.metrics.spaceUnit * 4
    implicitHeight: context.theme.metrics.barHeight

    Ui.ShellText {
        id: label

        anchors.centerIn: parent
        theme: root.context.theme
        text: root.displayText
        role: "secondary"
        sizeRole: "label"
        monospace: true
    }
}
