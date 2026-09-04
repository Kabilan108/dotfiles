// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

Item {
    id: root

    required property var theme
    property string label: "Value"
    property string accessibleName: ""
    property alias value: valueControl.value
    property alias from: valueControl.from
    property alias to: valueControl.to
    property alias stepSize: valueControl.stepSize
    property int decimals: 0
    property string suffix: ""
    property string valueText: ""
    property int trackHeight: 5
    property int trackBottomMargin: 5
    property bool busy: false
    property bool reducedMotion: false
    property bool keyboardFocused: false

    readonly property real minimum: Math.min(from, to)
    readonly property real maximum: Math.max(from, to)
    readonly property real position: valueControl.position
    readonly property bool canAdjust: enabled && !busy && maximum > minimum
    readonly property bool focusVisible: activeFocus || keyboardFocused
    readonly property string effectiveAccessibleName: accessibleName !== ""
        ? accessibleName
        : label

    signal moved(real value)

    activeFocusOnTab: canAdjust
    implicitWidth: 280
    implicitHeight: 44

    Keys.onPressed: function(event) {
        if (root.handleKey(event.key, event.modifiers, event.isAutoRepeat))
            event.accepted = true
    }

    Controls.Slider {
        id: valueControl

        visible: false
        from: 0
        to: 1
        value: 0.5
        stepSize: Math.abs(to - from) / 100
    }

    RowLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        ShellText {
            theme: root.theme
            text: root.label
            sizeRole: "caption"
            role: root.enabled ? "secondary" : "disabled"
        }

        Item {
            Layout.fillWidth: true
        }

        ShellBusyIndicator {
            visible: root.busy
            theme: root.theme
            reducedMotion: root.reducedMotion
            sizeRole: "small"
        }

        ShellText {
            theme: root.theme
            text: root.valueText !== ""
                ? root.valueText
                : Number(root.value).toFixed(root.decimals) + root.suffix
            sizeRole: "caption"
            monospace: true
            role: root.enabled ? "primary" : "disabled"
        }
    }

    Rectangle {
        id: track

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            bottomMargin: root.trackBottomMargin
        }
        height: root.trackHeight
        radius: height / 2
        color: root.theme.component.osd.track
        opacity: !root.enabled ? 0.6 : root.busy ? 0.82 : 1

        Rectangle {
            width: parent.width * root.position
            height: parent.height
            radius: parent.radius
            color: root.theme.component.osd.fill
        }

        Rectangle {
            x: Math.max(0, Math.min(parent.width - width,
                parent.width * root.position - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: height / 2
            color: root.theme.semantic.content.primary
            border.width: 2
            border.color: root.theme.component.osd.fill
        }

        MouseArea {
            id: pointer

            anchors {
                fill: parent
                topMargin: -10
                bottomMargin: -10
            }
            enabled: root.canAdjust
            cursorShape: root.canAdjust ? Qt.PointingHandCursor : Qt.ArrowCursor

            onPressed: function(mouse) {
                root.forceActiveFocus(Qt.MouseFocusReason)
                root._setFromPointer(mouse.x, mouse.y)
            }
            onPositionChanged: function(mouse) {
                if (pressed)
                    root._setFromPointer(mouse.x, mouse.y)
            }
        }
    }

    function handleKey(key, modifiers, autoRepeat) {
        if (!canAdjust)
            return false
        if (key === Qt.Key_Left || key === Qt.Key_Down)
            return adjustBySteps(-1)
        if (key === Qt.Key_Right || key === Qt.Key_Up)
            return adjustBySteps(1)
        if (key === Qt.Key_PageDown)
            return adjustBySteps(-10)
        if (key === Qt.Key_PageUp)
            return adjustBySteps(10)
        if (key === Qt.Key_Home)
            return moveTo(minimum)
        if (key === Qt.Key_End)
            return moveTo(maximum)
        return false
    }

    function adjustBySteps(steps) {
        var effectiveStep = stepSize > 0 ? stepSize : (maximum - minimum) / 100
        return moveTo(value + Number(steps) * effectiveStep)
    }

    function moveTo(nextValue) {
        if (!canAdjust)
            return false
        var next = _clamp(Number(nextValue))
        if (Math.abs(next - value) <= 0.0000001)
            return true
        moved(next)
        return true
    }

    function _setFromPointer(x, y) {
        var point = pointer.mapToItem(track, x, y)
        var fraction = Math.max(0, Math.min(1, point.x / Math.max(1, track.width)))
        moveTo(minimum + fraction * (maximum - minimum))
    }

    function _clamp(nextValue) {
        if (!isFinite(nextValue))
            return minimum
        return Math.max(minimum, Math.min(maximum, nextValue))
    }
}
