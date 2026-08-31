import QtQuick
import QtQuick.Layouts
import Quickshell
PanelWindow { id: root; required property var context; required property var service; required property string outputId; readonly property var power: context.services.get("stillsuit.power"); visible: false; implicitWidth: 360; implicitHeight: 300; color: "transparent"; exclusiveZone: 0; anchors { top: true; right: true }
 Rectangle { anchors.fill: parent; radius: root.context.theme.geometry.radius; color: root.context.theme.colors.surface.panel; border.color: root.context.theme.colors.border.normal; ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 10
 Text { text: "Power"; color: root.context.theme.colors.text.primary; font.pixelSize: root.context.theme.typography.baseSize + 3 }
 Text { text: !service || !service.available || !service.present ? "No battery" : service.percentage + "%  " + service.state; color: service && service.low ? root.context.theme.colors.status.error : root.context.theme.colors.text.primary }
 Text { text: service && service.timeText !== "" ? service.timeText + (service.discharging ? " left" : " to full") : ""; color: root.context.theme.colors.text.secondary }
 Rectangle { Layout.fillWidth: true; height: 8; radius: 4; color: root.context.theme.controls.normal.fill; Rectangle { width: parent.width * (service ? service.percentage / 100 : 0); height: parent.height; radius: 4; color: service && service.low ? root.context.theme.colors.status.error : service && service.charging ? root.context.theme.colors.status.success : root.context.theme.colors.status.info } }
 Text { text: "Power profile"; color: root.context.theme.colors.text.secondary }
 Repeater { model: power ? power.profiles : []
 delegate: Rectangle { required property var modelData; Layout.fillWidth: true; height: 30; radius: 4; color: modelData === root.power.activeProfile ? root.context.theme.controls.active.fill : root.context.theme.controls.normal.fill
 Text { anchors.centerIn: parent; text: modelData; color: root.context.theme.colors.text.primary }
 MouseArea { anchors.fill: parent; onClicked: root.power.setProfile(modelData) }
 } }
 } } function open(payloadJson) { visible = true } function close() { visible = false } }
