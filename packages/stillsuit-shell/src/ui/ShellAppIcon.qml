// SPDX-License-Identifier: MIT

import QtQuick
import Quickshell
import "IconCheck.js" as IconCheck

Item {
    id: root

    required property var theme
    property string icon: ""
    property string fallbackLabel: ""
    property string fallbackIconName: "circle"
    property string sizeRole: "large"
    property real pixelSize: _iconSize(sizeRole)
    readonly property url resolvedSource: _resolve(icon, _verdict)
    readonly property bool ready: image.status === Image.Ready && _verdict === IconCheck.USABLE

    property bool themeCheckAllowed: true
    property int _verdict: IconCheck.UNCHECKED

    onIconChanged: _syncVerdict()
    onThemeCheckAllowedChanged: _requestFrame()
    Component.onCompleted: _syncVerdict()

    Connections {
        target: root._verdict === IconCheck.UNCHECKED && root.themeCheckAllowed
                ? root.Window.window : null
        function onFrameSwapped() {
            if (image.status !== Image.Ready)
                return
            root._verdict = IconCheck.resolve(root._themeName(root.icon), function (name) {
                return Quickshell.iconPath(name, true)
            })
        }
    }

    implicitWidth: pixelSize
    implicitHeight: pixelSize

    Image {
        id: image
        anchors.fill: parent
        source: root.resolvedSource
        asynchronous: true
        cache: root._verdict !== IconCheck.UNCHECKED
        sourceSize.width: Math.ceil(width)
        sourceSize.height: Math.ceil(height)
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: root.ready
        onStatusChanged: root._requestFrame()
    }

    Rectangle {
        anchors.fill: parent
        visible: !root.ready && root.fallbackLabel !== ""
        radius: root.theme.metrics.radiusSmall
        color: root.theme.semantic.accent.subtle
        ShellText {
            anchors.centerIn: parent
            theme: root.theme
            text: root.fallbackLabel.charAt(0).toUpperCase()
            role: "accent"
            sizeRole: "label"
            font.pixelSize: Math.max(8, Math.round(root.pixelSize * 0.5))
        }
    }

    ShellIcon {
        anchors.fill: parent
        visible: !root.ready && root.fallbackLabel === ""
        theme: root.theme
        name: root.fallbackIconName
        role: "muted"
        pixelSize: root.pixelSize
    }

    function _resolve(value, verdict) {
        var name = String(value || "")
        if (name === "" || verdict === IconCheck.MISSING)
            return ""
        if (name.charAt(0) === "/")
            return "file://" + name.split("/").map(encodeURIComponent).join("/")
        return Quickshell.iconPath(name)
    }

    function _syncVerdict() {
        var name = _themeName(icon)
        _verdict = name === "" ? IconCheck.USABLE : IconCheck.known(name)
        _requestFrame()
    }

    function _requestFrame() {
        if (_verdict === IconCheck.UNCHECKED && themeCheckAllowed && image.status === Image.Ready
                && Window.window)
            Window.window.update()
    }

    function _themeName(value) {
        var name = String(value || "")
        return name.charAt(0) === "/" ? "" : name
    }

    function _lookupCount() {
        return IconCheck.lookups
    }

    function _iconSize(name) {
        if (name === "small")
            return theme.metrics.iconSmall
        if (name === "medium")
            return theme.metrics.iconMedium
        return theme.metrics.iconLarge
    }
}
