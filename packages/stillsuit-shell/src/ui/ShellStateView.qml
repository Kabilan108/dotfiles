// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var theme
    property string mode: "empty"
    property string title: ""
    property string message: ""
    property string iconName: ""
    property string actionLabel: ""
    property string accessibleName: ""
    property bool reducedMotion: false

    readonly property string effectiveAccessibleName: accessibleName !== ""
        ? accessibleName
        : _resolvedTitle()

    signal actionRequested()

    implicitWidth: 300
    implicitHeight: 112

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width, 300)
        spacing: 5

        ShellBusyIndicator {
            visible: root.mode === "loading"
            Layout.alignment: Qt.AlignHCenter
            theme: root.theme
            reducedMotion: root.reducedMotion
            sizeRole: "large"
        }

        ShellIcon {
            visible: root.mode !== "loading"
            Layout.alignment: Qt.AlignHCenter
            theme: root.theme
            name: root.iconName !== "" ? root.iconName : root._resolvedIcon()
            sizeRole: "large"
            role: root.mode === "error" ? "danger" : "muted"
        }

        ShellText {
            Layout.fillWidth: true
            theme: root.theme
            text: root._resolvedTitle()
            sizeRole: "label"
            role: root.mode === "error" ? "danger" : "primary"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        ShellText {
            visible: root.message !== ""
            Layout.fillWidth: true
            theme: root.theme
            text: root.message
            sizeRole: "caption"
            role: "muted"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        ShellButton {
            visible: root.actionLabel !== "" && root.mode !== "loading"
            Layout.alignment: Qt.AlignHCenter
            theme: root.theme
            label: root.actionLabel
            accessibleName: root.actionLabel
            compact: true
            ghost: true
            destructive: root.mode === "error"
            reducedMotion: root.reducedMotion
            onClicked: root.actionRequested()
        }
    }

    function _resolvedTitle() {
        if (title !== "")
            return title
        if (mode === "loading")
            return "Loading"
        if (mode === "error")
            return "Something went wrong"
        return "Nothing here"
    }

    function _resolvedIcon() {
        return mode === "error" ? "danger" : "info"
    }
}
