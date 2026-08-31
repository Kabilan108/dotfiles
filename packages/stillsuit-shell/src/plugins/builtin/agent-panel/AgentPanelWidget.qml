import QtQuick

Rectangle {
  id: root

  required property var context

  readonly property var theme: context.theme

  implicitWidth: Math.max(36, label.implicitWidth + 18)
  implicitHeight: theme.geometry.barHeight
  radius: theme.geometry.radius
  color: pointer.containsMouse ? theme.controls.hover.fill : "transparent"

  Text {
    id: label
    anchors.centerIn: parent
    text: "⌁ AI"
    color: root.theme.colors.text.primary
    font.family: root.theme.typography.monospaceFamily
    font.pixelSize: root.theme.typography.baseSize
    font.weight: root.theme.typography.weightMedium
  }

  MouseArea {
    id: pointer
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        root.context.actions.agentPanelHide()
      else if (mouse.button === Qt.MiddleButton)
        root.context.actions.agentPanelStatus()
      else
        root.context.actions.agentPanelToggle()
    }
  }
}
