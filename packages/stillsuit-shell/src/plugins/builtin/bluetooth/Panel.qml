import QtQuick
import QtQuick.Layouts
import Quickshell
PanelWindow { id: root; required property var context; required property var service; required property string outputId; visible: false; implicitWidth: 360; implicitHeight: 390; color: "transparent"; exclusiveZone: 0; anchors { top: true; right: true }
 Rectangle { anchors.fill: parent; radius: root.context.theme.geometry.radius; color: root.context.theme.colors.surface.panel; border.color: root.context.theme.colors.border.normal; ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 8
 Text { text: "Bluetooth"; color: root.context.theme.colors.text.primary; font.pixelSize: root.context.theme.typography.baseSize + 3 }
 Row { spacing: 8
 Rectangle { width: 100; height: 28; radius: 4; color: toggleMouse.containsMouse ? root.context.theme.controls.hover.fill : root.context.theme.controls.normal.fill
 Text { anchors.centerIn: parent; text: service && service.enabled ? "Enabled" : "Disabled"; color: root.context.theme.colors.text.primary }
 MouseArea { id: toggleMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.service.setEnabled(!root.service.enabled) }
 }
 Rectangle { width: 72; height: 28; radius: 4; color: scanMouse.containsMouse ? root.context.theme.controls.hover.fill : root.context.theme.controls.normal.fill
 Text { anchors.centerIn: parent; text: "Scan"; color: root.context.theme.colors.text.primary }
 MouseArea { id: scanMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.service.scan() }
 } }
 ListView { Layout.fillWidth: true; Layout.fillHeight: true; clip: true; model: service ? service.devices : []
 delegate: Rectangle { required property var modelData; width: ListView.view.width; height: 40; color: devMouse.containsMouse ? root.context.theme.controls.hover.fill : "transparent"
 Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 8; text: (modelData.name || modelData.address || "unknown") + (modelData.connected ? "  connected" : ""); color: root.context.theme.colors.text.primary }
 MouseArea { id: devMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.service.toggle(modelData) }
 } }
 } } function open(payloadJson) { visible = true } function close() { visible = false } }
