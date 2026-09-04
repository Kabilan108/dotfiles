// SPDX-License-Identifier: MIT
// Interaction contract informed by Omarchy Quattro shell/Ui/Button.qml at
// f0020448ca87329199de7cb12f2015ebc4a3e5e7.
// Copyright (c) David Heinemeier Hansson

import QtQuick

Item {
    id: root

    property bool busy: false
    property bool interactive: true
    property string accessibleName: ""
    property string accessibleFallback: ""
    property bool keyboardFocused: false

    readonly property bool canActivate: interactive && enabled && !busy
    readonly property bool hovered: pointer.containsMouse
    readonly property bool pressed: pointer.pressed
    readonly property bool focusVisible: activeFocus || keyboardFocused
    readonly property string effectiveAccessibleName: accessibleName !== ""
        ? accessibleName
        : accessibleFallback

    signal activated()

    activeFocusOnTab: canActivate

    Keys.onPressed: function(event) {
        if (root.handleKey(event.key, event.modifiers, event.isAutoRepeat))
            event.accepted = true
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.canActivate
        hoverEnabled: true
        cursorShape: root.canActivate ? Qt.PointingHandCursor : Qt.ArrowCursor

        onPressed: root.forceActiveFocus(Qt.MouseFocusReason)
        onClicked: root.trigger()
    }

    function trigger() {
        if (!canActivate)
            return false
        activated()
        return true
    }

    function handleKey(key, modifiers, autoRepeat) {
        if (!canActivate || autoRepeat)
            return false
        if (key !== Qt.Key_Return && key !== Qt.Key_Enter && key !== Qt.Key_Space)
            return false
        return trigger()
    }
}
