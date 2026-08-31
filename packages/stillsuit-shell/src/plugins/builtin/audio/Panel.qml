import QtQuick
import QtQuick.Layouts
import Quickshell
PanelWindow {
    id: root
    required property var context
    required property var service
    required property string outputId
    visible: false; implicitWidth: 360; implicitHeight: 250; color: "transparent"; exclusiveZone: 0
    anchors { top: true; right: true }
    Rectangle { anchors.fill: parent; radius: root.context.theme.geometry.radius; color: root.context.theme.colors.surface.panel; border.color: root.context.theme.colors.border.normal
        ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 12
            Text { text: "Audio"; color: root.context.theme.colors.text.primary; font.pixelSize: root.context.theme.typography.baseSize + 3 }
            Text { text: service && service.available ? service.outputName : "PipeWire unavailable"; color: root.context.theme.colors.text.secondary }
            SliderRow { label: "Output"; value: service ? service.volume : 0; enabled: service && service.available; onChanged: function(value) { service.setVolume(value) } }
            Button { text: service && service.muted ? "Unmute" : "Mute"; onClicked: if (service) service.toggleMuted() }
            Text { text: "Input: " + (service ? service.inputName : "unavailable"); color: root.context.theme.colors.text.secondary }
        }
    }
    function open(payloadJson) { visible = true }
    function close() { visible = false }
    component SliderRow: Column {
        property string label
        property real value
        signal changed(real value)
        spacing: 5
        Text { text: parent.label + " " + Math.round(parent.value * 100) + "%"; color: root.context.theme.colors.text.primary }
        Rectangle {
            width: 320; height: 6; radius: 3; color: root.context.theme.controls.normal.fill
            Rectangle { width: parent.width * Math.min(1, parent.parent.value); height: parent.height; radius: 3; color: root.context.theme.colors.status.info }
            MouseArea { anchors.fill: parent; onClicked: parent.parent.changed(mouse.x / parent.width) }
        }
    }
    component Button: Rectangle {
        property string text
        signal clicked()
        implicitWidth: 88; implicitHeight: 28; radius: 4
        color: buttonMouse.containsMouse ? root.context.theme.controls.hover.fill : root.context.theme.controls.normal.fill
        Text { anchors.centerIn: parent; text: parent.text; color: root.context.theme.colors.text.primary }
        MouseArea { id: buttonMouse; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
    }
}
