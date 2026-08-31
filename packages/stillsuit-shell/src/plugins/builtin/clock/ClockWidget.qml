import QtQuick

Rectangle {
    id: root

    required property var context
    required property var service
    required property string outputId

    implicitWidth: label.implicitWidth + 20
    implicitHeight: context.theme.geometry.barHeight
    radius: context.theme.geometry.radius
    color: "transparent"

    Text {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(root.service.now, "MM-dd-yyyy  HH:mm")
        color: root.context.theme.colors.text.secondary
        font.family: root.context.theme.typography.monospaceFamily
        font.pixelSize: root.context.theme.typography.baseSize
        font.weight: root.context.theme.typography.weightMedium
    }

}
