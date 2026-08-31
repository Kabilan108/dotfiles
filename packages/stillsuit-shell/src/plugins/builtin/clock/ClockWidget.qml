import QtQuick

Rectangle {
    id: root

    required property var context
    property date now: new Date()

    implicitWidth: label.implicitWidth + 20
    implicitHeight: context.theme.geometry.barHeight
    radius: context.theme.geometry.radius
    color: "transparent"

    Text {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(root.now, "MM-dd-yyyy  HH:mm")
        color: root.context.theme.colors.text.secondary
        font.family: root.context.theme.typography.monospaceFamily
        font.pixelSize: root.context.theme.typography.baseSize
        font.weight: root.context.theme.typography.weightMedium
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
}
