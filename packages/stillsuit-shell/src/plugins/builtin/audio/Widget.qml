import QtQuick
Rectangle {
    id: root
    required property var context
    readonly property var audio: context.services.get("stillsuit.audio")
    implicitWidth: 76; implicitHeight: context.theme.geometry.barHeight
    radius: context.theme.geometry.radius
    color: mouse.containsMouse ? context.theme.controls.hover.fill : "transparent"
    Text { anchors.centerIn: parent; text: !audio || !audio.available ? "VOL --" : audio.muted ? "VOL mute" : "VOL " + Math.round(audio.volume * 100) + "%"; color: root.context.theme.colors.text.primary; font.family: root.context.theme.typography.monospaceFamily; font.pixelSize: root.context.theme.typography.baseSize }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.context.actions.surfaceToggle("stillsuit.audio", "") }
}
