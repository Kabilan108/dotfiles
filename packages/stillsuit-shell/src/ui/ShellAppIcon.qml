// SPDX-License-Identifier: MIT

import QtQuick
import Quickshell
import "IconCheck.js" as IconCheck

Item {
    id: root

    required property var theme
    // A freedesktop icon name ("org.gnome.Nautilus") or an absolute path.
    property string icon: ""
    // Shown as a monogram when the icon cannot be resolved; the catalog
    // glyph is used when this is empty.
    property string fallbackLabel: ""
    property string fallbackIconName: "circle"
    property string sizeRole: "large"
    property real pixelSize: _iconSize(sizeRole)
    readonly property url resolvedSource: _resolve(icon, _verdict)
    readonly property bool ready: image.status === Image.Ready && _verdict === IconCheck.USABLE

    // Quickshell's icon provider draws a placeholder for a name the theme
    // lacks, so a themed name only counts once the theme has confirmed it.
    // That lookup is synchronous and can take most of a second while the
    // theme is cold. On a surface that is about to take keyboard focus it
    // would hold back the request for that focus, and typing meant for the
    // surface would reach the previous window. So no binding asks the theme.
    // A name is looked up once, on the GUI thread, only after the provider
    // has loaded its image on the pixmap reader thread, which has just paid
    // the theme cost for that name, and after the next frame while lookups
    // are allowed. Until then the image skips the pixmap cache: a cached
    // image is Ready without that load, and its theme entry may have been
    // evicted since. A surface that takes keyboard focus also sets this to
    // `Window.active`, which turns true once the compositor has handed it the
    // keyboard.
    property bool themeCheckAllowed: true
    property int _verdict: IconCheck.UNCHECKED

    onIconChanged: _syncVerdict()
    onThemeCheckAllowedChanged: _requestFrame()
    Component.onCompleted: _syncVerdict()

    Connections {
        target: root._verdict === IconCheck.UNCHECKED && root.themeCheckAllowed ? root.Window.window : null
        function onFrameSwapped() {
            if (image.status !== Image.Ready)
                return
            root._verdict = IconCheck.resolve(root._themeName(root.icon), function(name) {
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

    // A window whose content looks the same would not draw again.
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
