// SPDX-License-Identifier: MIT
// Adapted from Omarchy Quattro shell/Ui/Panel.qml at
// f0020448ca87329199de7cb12f2015ebc4a3e5e7.
// Copyright (c) David Heinemeier Hansson
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import QtQuick

Rectangle {
    id: root

    default property alias content: body.data
    property var context: null
    property QtObject bar: null
    property string moduleName: ""
    property var settings: ({})
    property string outputId: ""
    property bool opened: false
    property bool popoutSwitching: false
    property bool popoutSwitchClosing: false
    property string lastPayloadJson: ""
    property int padding: Math.round(14 * _density())
    readonly property QtObject controller: panelController
    readonly property color barForeground: bar && bar.barForeground !== undefined
        ? bar.barForeground
        : _themeColor("colors", "text", "primary", "#cdd6f4")

    signal openedWithPayload(string payloadJson)
    signal closed()

    visible: opened
    implicitWidth: 380
    implicitHeight: body.childrenRect.height + padding * 2
    radius: _themeValue("geometry", "radius", 6)
    color: _themeColor("colors", "surface", "panel", "#181825")
    border.width: 1
    border.color: _themeColor("colors", "border", "normal", "#45475a")
    clip: true

    Behavior on opacity {
        NumberAnimation {
            duration: root._themeValue("motion", "fast", 120)
        }
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: root.padding
    }

    QtObject {
        id: panelController

        readonly property bool open: root.opened

        function show(payloadJson) {
            root.open(payloadJson)
        }

        function hide() {
            root.close()
        }
    }

    function open(payloadJson) {
        lastPayloadJson = String(payloadJson || "")
        opened = true
        openedWithPayload(lastPayloadJson)
    }

    function close() {
        if (!opened)
            return
        opened = false
        closed()
    }

    function closeForPopoutSwitch() {
        popoutSwitchClosing = true
        close()
        Qt.callLater(function() {
            popoutSwitchClosing = false
        })
    }

    function toggle(payloadJson) {
        if (opened)
            close()
        else
            open(payloadJson)
    }

    function switchPanel(direction) {
        if (bar && typeof bar.switchPanelFrom === "function")
            return bar.switchPanelFrom(root, direction)
        return false
    }

    function setting(name, fallback) {
        var value = settings ? settings[name] : undefined
        return value === undefined || value === null ? fallback : value
    }

    function _density() {
        return _themeValue("geometry", "density", 1)
    }

    function _themeValue(group, key, fallback) {
        var theme = context ? context.theme : null
        return theme && theme[group] && theme[group][key] !== undefined
            ? theme[group][key]
            : fallback
    }

    function _themeColor(group, subgroup, key, fallback) {
        var theme = context ? context.theme : null
        return theme && theme[group] && theme[group][subgroup]
                && theme[group][subgroup][key] !== undefined
            ? theme[group][subgroup][key]
            : fallback
    }
}
