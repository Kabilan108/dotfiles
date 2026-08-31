// SPDX-License-Identifier: MIT
// Adapted from Omarchy Quattro shell/Ui/PanelKeyCatcher.qml at
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

Item {
    id: root

    property bool blocked: false

    signal moveRequested(int dx, int dy)
    signal activateRequested()
    signal returnRequested()
    signal closeRequested()
    signal deleteRequested()
    signal tabRequested(int direction)
    signal textKey(string text)

    focus: true
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
        if (blocked)
            return

        if (event.key === Qt.Key_Escape) {
            closeRequested()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            tabRequested((event.modifiers & Qt.ShiftModifier)
                || event.key === Qt.Key_Backtab ? -1 : 1)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Down || event.text === "j") {
            moveRequested(0, 1)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Up || event.text === "k") {
            moveRequested(0, -1)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Right || event.text === "l") {
            moveRequested(1, 0)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Left || event.text === "h") {
            moveRequested(-1, 0)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            returnRequested()
            activateRequested()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Space) {
            activateRequested()
            event.accepted = true
            return
        }
        if (event.text === "x" || event.text === "X") {
            deleteRequested()
            event.accepted = true
            return
        }
        if (event.text && event.text.length === 1)
            textKey(event.text)
    }
}
