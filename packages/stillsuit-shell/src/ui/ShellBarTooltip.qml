// SPDX-License-Identifier: MIT
import QtQuick
import Quickshell

Item {
    id: root
    required property var theme
    required property Item target
    property string text: ""
    property bool hovering: false
    property bool showing: false
    readonly property var popupWindow: popupLoader.item
    onHoveringChanged: {
        showing = false
        if (hovering && text !== "") delay.restart()
        else delay.stop()
    }
    Timer {
        id: delay
        interval: 500
        onTriggered: root.showing = root.hovering && root.text !== ""
    }
    Loader {
        id: popupLoader
        active: root.showing && root.visible && root.text !== ""
        sourceComponent: Component {
            PopupWindow {
                id: popup
                visible: true
                color: "transparent"
                implicitWidth: Math.min(320, label.implicitWidth + 20)
                implicitHeight: label.contentHeight + 16
                mask: Region {}
                anchor.item: root.target
                anchor.rect.y: root.target.height + 4
                ShellSurface {
                    anchors.fill: parent
                    theme: root.theme
                    ShellText {
                        id: label
                        anchors.fill: parent
                        anchors.margins: 8
                        theme: root.theme
                        text: root.text
                        textFormat: Text.PlainText
                        sizeRole: "caption"
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
