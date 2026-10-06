// SPDX-License-Identifier: MIT

import QtQuick

FocusScope {
    id: root

    required property var theme
    property alias text: input.text
    property string placeholderText: ""
    property string iconName: ""
    property string iconRole: "muted"
    property string accessibleName: placeholderText
    readonly property alias inputItem: input
    readonly property real cursorWidth: 2

    // Emitted before the field edits text. Accept the event to keep it from
    // the field, for keys such as Up, Down, Tab, or Ctrl+K that a parent owns.
    // Unaccepted keys the field ignores (Escape, Up, Down) keep propagating
    // to parent items.
    signal keyPressed(var event)
    signal accepted()

    implicitWidth: 240
    implicitHeight: input.implicitHeight + theme.metrics.spaceUnit * 2

    function selectAll() { input.selectAll() }
    function clear() { input.clear() }

    Rectangle {
        anchors.fill: parent
        radius: root.theme.metrics.radiusMedium
        color: root.theme.component.control.background
        border.width: 1
        border.color: input.activeFocus
            ? root.theme.component.control.focus
            : root.theme.component.control.outline
    }

    ShellIcon {
        id: leadingIcon
        theme: root.theme
        visible: root.iconName !== ""
        name: root.iconName !== "" ? root.iconName : "circle"
        role: root.iconRole
        sizeRole: "small"
        anchors.left: parent.left
        anchors.leftMargin: root.theme.metrics.spaceUnit
        anchors.verticalCenter: parent.verticalCenter
    }

    TextInput {
        id: input
        focus: true
        anchors.left: leadingIcon.visible ? leadingIcon.right : parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.theme.metrics.spaceUnit
        anchors.rightMargin: root.theme.metrics.spaceUnit
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: root.theme.component.control.text
        selectionColor: root.theme.semantic.surface.selected
        selectedTextColor: root.theme.semantic.content.primary
        selectByMouse: true
        font.family: root.theme.typography.bodyFamily
        font.pixelSize: root.theme.typography.baseSize
        renderType: Text.NativeRendering
        Accessible.name: root.accessibleName
        cursorDelegate: Rectangle {
            width: root.cursorWidth
            color: root.theme.semantic.accent.primary
            visible: input.cursorVisible
        }
        Keys.onPressed: event => root.keyPressed(event)
        onAccepted: root.accepted()
    }

    // The caret sits at the start of an empty field; the placeholder starts
    // just past it so the two don't touch.
    ShellText {
        theme: root.theme
        anchors.fill: input
        anchors.leftMargin: root.cursorWidth + root.theme.metrics.spaceUnit / 2
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: root.placeholderText
        role: "muted"
        visible: input.text.length === 0 && input.preeditText.length === 0
    }
}
