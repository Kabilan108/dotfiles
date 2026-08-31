import QtQuick

Rectangle {
    id: root
    required property var context
    readonly property var battery: context.services.get("stillsuit.battery")
    implicitWidth: 70
    implicitHeight: context.theme.geometry.barHeight
    radius: context.theme.geometry.radius
    color: mouse.containsMouse ? context.theme.controls.hover.fill : "transparent"
    visible: battery && battery.present
    Text { anchors.centerIn: parent; text: battery && battery.charging ? "BAT +" + battery.percentage + "%" : "BAT " + (battery ? battery.percentage : "--") + "%"; color: battery && battery.low ? root.context.theme.colors.status.error : root.context.theme.colors.text.primary; font.family: root.context.theme.typography.monospaceFamily; font.pixelSize: root.context.theme.typography.baseSize }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.context.actions.surfaceToggle("stillsuit.battery", "") }
}
