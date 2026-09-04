// SPDX-License-Identifier: MIT

import QtQuick

ShellIcon {
    id: root

    property bool reducedMotion: false
    property bool running: visible
    readonly property int motionDuration: reducedMotion || theme.motion.slow <= 0
        ? 0
        : Math.max(1, theme.motion.slow * 4)

    name: "refresh"
    role: "accent"
    rotation: 0
    transformOrigin: Item.Center

    RotationAnimation on rotation {
        from: 0
        to: 360
        duration: root.motionDuration > 0 ? root.motionDuration : 1
        loops: Animation.Infinite
        running: root.running && root.motionDuration > 0
    }
}
