import QtQuick
import QtQuick.Layouts
import Quickshell
PanelWindow { id: root; required property var context; required property var service; required property string outputId; visible: false; implicitWidth: 380; implicitHeight: 420; color: "transparent"; exclusiveZone: 0; anchors { top: true; right: true }
 Rectangle { anchors.fill: parent; radius: root.context.theme.geometry.radius; color: root.context.theme.colors.surface.panel; border.color: root.context.theme.colors.border.normal; ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 8
 Text { text: "Network"; color: root.context.theme.colors.text.primary; font.pixelSize: root.context.theme.typography.baseSize + 3 }
 Text { text: !service || !service.available ? "NetworkManager unavailable" : service.wiredConnected ? "Wired connected" : service.connectedNetwork ? "Connected to " + service.connectedNetwork.name : "Not connected"; color: root.context.theme.colors.text.secondary }
 Row { spacing: 8
 Repeater { model: ["Scan", service && service.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off"]
 delegate: Rectangle { required property var modelData; width: 90; height: 28; radius: 4; color: btn.containsMouse ? root.context.theme.controls.hover.fill : root.context.theme.controls.normal.fill
 Text { anchors.centerIn: parent; text: modelData; color: root.context.theme.colors.text.primary }
 MouseArea { id: btn; anchors.fill: parent; hoverEnabled: true; onClicked: index === 0 ? service.scan() : service.setWifiEnabled(!service.wifiEnabled) }
 } } }
 ListView { Layout.fillWidth: true; Layout.fillHeight: true; clip: true; model: service ? service.networks : []
 delegate: Rectangle { required property var modelData; width: ListView.view.width; height: 38; color: rowMouse.containsMouse ? root.context.theme.controls.hover.fill : "transparent"
 Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 8; text: modelData.name + (modelData.connected ? "  connected" : modelData.known ? "  saved" : ""); color: root.context.theme.colors.text.primary }
 MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.service.activate(modelData) }
 } }
 } } function open(payloadJson) { visible = true } function close() { visible = false } }
