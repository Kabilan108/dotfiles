// SPDX-License-Identifier: MIT
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var router
    required property var theme
    required property string outputId
    property Item menuContent: null
    readonly property bool shown: menuContent !== null
    readonly property bool drawn: shown && width > 1 && height > 1
    property Region emptyRegion: Region {}

    visible: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        left: true
        bottom: root.shown
        right: root.shown
    }
    implicitWidth: 1
    implicitHeight: 1
    mask: shown ? null : emptyRegion
    WlrLayershell.namespace: "stillsuit.menu"
    WlrLayershell.layer: shown ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onDrawnChanged: if (drawn)
                        remapTimer.stop()
    onShownChanged: {
        renderedSinceShown = false
        remapTimer.waits = 0
        if (shown && !drawn)
            remapTimer.restart()
        else
            remapTimer.stop()
    }

    property bool renderedSinceShown: false
    Connections {
        target: root.shown && !root.drawn ? stage.Window.window : null
        function onAfterAnimating() {
            root.renderedSinceShown = true
        }
    }
    Timer {
        id: remapTimer
        property int waits: 0
        interval: 50
        repeat: true
        onTriggered: {
            if (!root.shown || root.drawn) {
                stop()
                return
            }
            if (root.renderedSinceShown && ++waits < 3)
                return
            stop()
            root.visible = false
            root.visible = true
        }
    }

    Item {
        id: stage
        objectName: "menu-host-stage"
        anchors.fill: parent
        opacity: root.drawn ? 1 : 0
        MouseArea {
            id: scrim
            objectName: "menu-host-scrim"
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            function outside(x, y) {
                var point = mapToItem(contentArea, x, y)
                return point.x < 0 || point.y < 0 || point.x >= contentArea.width || point.y
                        >= contentArea.height
            }
            function handlePress(x, y) {
                if (outside(x, y))
                    root.router.dismissMenus()
            }
            onPressed: mouse => handlePress(mouse.x, mouse.y)
            Rectangle {
                anchors.fill: parent
                color: {
                    var scrimColor = Qt.color(root.theme.semantic.background.scrim)
                    return Qt.rgba(scrimColor.r, scrimColor.g, scrimColor.b,
                                   root.theme.effects.shadowOpacity)
                }
            }
        }
        Item {
            id: contentArea
            objectName: "menu-host-content"
            readonly property real edge: root.theme.metrics.spaceUnit
            x: Math.round((root.width - width) / 2)
            y: Math.round(root.height * 0.22)
            width: Math.min(root.menuContent ? root.menuContent.implicitWidth : 0, Math.max(0, root.width
                                                                                            - edge * 2))
            height: Math.min(root.menuContent ? root.menuContent.implicitHeight : 0, Math.max(0,
                                                                                              root.height
                                                                                              - y - edge))
            Keys.onEscapePressed: root.router.dismissMenus()
        }
    }
    function present(item) {
        if (menuContent && menuContent !== item)
            dismiss(menuContent)
        menuContent = item
        item.parent = contentArea
        if (menuContent !== item)
            return
        item.anchors.fill = contentArea
        item.visible = true
        item.forceActiveFocus()
    }
    function dismiss(item) {
        if (!item || item !== menuContent)
            return
        item.visible = false
        item.parent = null
        menuContent = null
    }
    Component.onCompleted: router.registerMenuHost(outputId, root)
    Component.onDestruction: {
        if (menuContent)
            menuContent.parent = null
        router.unregisterMenuHost(outputId, root)
    }
}
