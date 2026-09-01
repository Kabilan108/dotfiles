// SPDX-License-Identifier: MIT
// Adapted from Omarchy Quattro shell/Ui/CursorSurface.qml at
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

    property var context: null
    property bool hasCursor: false
    property bool current: false
    property bool outline: false
    property bool bordered: false
    property color foreground: _themeColor("colors", "text", "primary", "#cdd6f4")
    property color accent: _themeColor("colors", "border", "focus", foreground)
    property color fill: _controlColor("hover", "fill", "#313244")
    property color currentFill: _controlColor("active", "fill", "#45475a")

    radius: _themeValue("geometry", "radius", 6)
    color: hasCursor
        ? fill
        : current
            ? currentFill
            : "transparent"
    border.width: hasCursor || current || bordered ? 1 : 0
    border.color: hasCursor
        ? _controlColor("hover", "border", "#585b70")
        : current
            ? _controlColor("active", "border", "#89b4fa")
            : _themeColor("colors", "border", "subtle", "#313244")

    Behavior on color {
        ColorAnimation {
            duration: root._themeValue("motion", "fast", 120)
        }
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

    function _controlColor(state, key, fallback) {
        var theme = context ? context.theme : null
        return theme && theme.controls && theme.controls[state]
                && theme.controls[state][key] !== undefined
            ? theme.controls[state][key]
            : fallback
    }
}
