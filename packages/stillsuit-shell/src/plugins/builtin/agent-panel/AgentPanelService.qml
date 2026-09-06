import QtQuick

QtObject {
  required property var context

  readonly property string apiVersion: "1"

  function open() {
    return context.actions.agentPanelOpen()
  }

  function hide() {
    return context.actions.agentPanelHide()
  }

  function toggle() {
    return context.actions.agentPanelToggle()
  }

  function status() {
    return context.actions.agentPanelStatus()
  }

  function terminate() {
    return context.actions.agentPanelTerminate()
  }
}
