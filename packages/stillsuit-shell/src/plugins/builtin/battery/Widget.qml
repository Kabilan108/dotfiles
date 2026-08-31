import QtQuick

Rectangle {
    id: root
    required property var context
    required property var service
    required property string outputId
    implicitWidth: 70
    implicitHeight: context.theme.geometry.barHeight
    radius: context.theme.geometry.radius
    color: mouse.containsMouse ? context.theme.controls.hover.fill : "transparent"
    visible: service && service.available && service.present
    Text { anchors.centerIn: parent; text: service && service.charging ? "BAT +" + service.percentage + "%" : "BAT " + (service ? service.percentage : "--") + "%"; color: service && service.low ? root.context.theme.colors.status.error : root.context.theme.colors.text.primary; font.family: root.context.theme.typography.monospaceFamily; font.pixelSize: root.context.theme.typography.baseSize }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.context.actions.surfaceToggle("stillsuit.battery", "") }
}
