// SPDX-License-Identifier: MIT
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var router
    required property var theme
    required property string outputId
    property Item panelContent: null
    color: "transparent"
    // Geometry below is in output coordinates, including the bar's reserved
    // height. Respecting its exclusive zone here would count that height twice.
    exclusionMode: ExclusionMode.Ignore
    visible: panelContent !== null
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.namespace: "stillsuit.panel"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // Leave the bar outside the input region so a single click reaches the
    // next entry even while this host is open.
    mask: Region { item: dismissArea }
    MouseArea {
        id: dismissArea
        anchors.fill: parent
        anchors.topMargin: root.theme.metrics.barHeight + root.theme.metrics.barOuterGap
        acceptedButtons: Qt.AllButtons
        function outside(x, y) {
            var point = mapToItem(contentArea, x, y)
            return point.x < 0 || point.y < 0
                || point.x >= contentArea.width || point.y >= contentArea.height
        }
        onPressed: mouse => {
            if (outside(mouse.x, mouse.y)) root.router.dismissPanels()
        }
        onWheel: wheel => {
            if (outside(wheel.x, wheel.y)) root.router.dismissPanels()
        }
    }
    Item {
        id: contentArea
        x: Math.max(0, root.width - width - root.theme.metrics.spaceUnit)
        y: root.theme.metrics.barHeight + root.theme.metrics.barOuterGap
            + root.theme.metrics.spaceUnit
        width: Math.min(root.panelContent ? root.panelContent.implicitWidth : 0,
            Math.max(0, root.width - root.theme.metrics.spaceUnit * 2))
        height: Math.min(root.panelContent ? root.panelContent.implicitHeight : 0,
            Math.max(0, root.height - y - root.theme.metrics.spaceUnit))
        clip: true
        Keys.onEscapePressed: root.router.dismissPanels()
    }
    function present(item) {
        if (panelContent && panelContent !== item) panelContent.visible = false
        panelContent = item
        item.parent = contentArea
        item.anchors.fill = contentArea
        item.visible = true
        contentArea.forceActiveFocus()
    }
    function dismiss(item) {
        if (item) {
            item.visible = false
            item.parent = null
        }
        if (panelContent === item) panelContent = null
    }
    Component.onCompleted: router.registerPanelHost(outputId, root)
    Component.onDestruction: {
        // Keep cached plugin objects out of the dying window's visual tree.
        if (panelContent) panelContent.parent = null
        router.unregisterPanelHost(outputId, root)
    }
}
