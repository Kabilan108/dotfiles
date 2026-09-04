// SPDX-License-Identifier: MIT
// Adapted from Omarchy Quattro shell/Ui/PointerMoveGate.qml at
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

QtObject {
    id: root

    property Item referenceItem: null
    property real threshold: 1
    property bool primed: false
    property bool initialSampleAllowed: false
    property real lastX: 0
    property real lastY: 0

    function reset() {
        primed = false
        initialSampleAllowed = false
        lastX = 0
        lastY = 0
    }

    function allowInitialSample() {
        reset()
        initialSampleAllowed = true
    }

    function moved(item, mouse) {
        if (!item || !mouse) {
            reset()
            return false
        }

        var target = referenceItem || item
        var point = item.mapToItem(target, mouse.x, mouse.y)
        var firstSample = !primed
        var didMove = firstSample
            ? initialSampleAllowed
            : Math.abs(point.x - lastX) > threshold
                || Math.abs(point.y - lastY) > threshold

        if (firstSample || didMove) {
            lastX = point.x
            lastY = point.y
        }
        primed = true
        initialSampleAllowed = false
        return didMove
    }
}
