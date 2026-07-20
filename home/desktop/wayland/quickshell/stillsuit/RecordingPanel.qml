import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    required property var controller

    component IconButton: Rectangle {
        id: iconButton

        property string icon: ""
        property color iconColor: Theme.textTertiary
        property bool quiet: false
        property int iconSize: 19

        signal clicked()

        implicitWidth: 38
        implicitHeight: 38
        radius: Theme.radiusSmall
        color: buttonMouse.pressed ? Theme.panelSurfaceActive
            : buttonMouse.containsMouse ? Theme.panelSurfaceHover
            : quiet ? "transparent" : Theme.panelSurface
        border.width: quiet ? 0 : Theme.borderWidth
        border.color: Theme.panelBorder

        Text {
            anchors.centerIn: parent
            text: iconButton.icon
            color: iconButton.iconColor
            font.family: Theme.iconFamily
            font.pixelSize: iconButton.iconSize
            font.variableAxes: ({ "FILL": 0, "wght": 500, "opsz": 20 })
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconButton.clicked()
        }
    }

    component AudioToggle: Rectangle {
        id: audioToggle

        property string icon: ""
        property string label: ""
        property bool on: false
        property color accentColor: Theme.accent

        signal toggled()

        implicitHeight: 42
        radius: Theme.radiusSmall
        color: on
            ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.13)
            : toggleMouse.containsMouse ? Theme.panelSurfaceHover : Theme.panelSurface
        border.width: Theme.borderWidth
        border.color: on
            ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.42)
            : Theme.panelBorder

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 9

            Text {
                text: audioToggle.icon
                color: audioToggle.on ? audioToggle.accentColor : Theme.textMuted
                font.family: Theme.iconFamily
                font.pixelSize: 17
                font.variableAxes: ({ "FILL": audioToggle.on ? 1 : 0, "wght": 500, "opsz": 20 })
            }

            Text {
                Layout.fillWidth: true
                text: audioToggle.label
                color: audioToggle.on ? Theme.textPrimary : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                text: audioToggle.on ? "ON" : "OFF"
                color: audioToggle.on ? audioToggle.accentColor : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.2
            }
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: audioToggle.toggled()
        }
    }

    LazyLoader {
        active: root.controller.visible

        PanelWindow {
            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            margins.top: Theme.barHeight + Theme.screenMargin + Theme.panelGap
            exclusiveZone: 0
            focusable: true
            color: "transparent"
            WlrLayershell.namespace: "stillsuit-recording"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            MouseArea {
                anchors.fill: parent
                onClicked: root.controller.close()
            }

            MouseArea {
                anchors.fill: recorderPanel
                onClicked: {}
            }

            PopupPanel {
                id: recorderPanel
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                implicitWidth: root.controller.active ? transportRow.implicitWidth + padding * 2
                    : root.controller.completed ? 460
                    : 452
                padding: root.controller.active ? 14 : root.controller.completed ? 20 : 18
                focus: true
                Keys.onEscapePressed: root.controller.close()

                ColumnLayout {
                    visible: root.controller.phase === "idle"
                    Layout.preferredWidth: recorderPanel.implicitWidth - recorderPanel.padding * 2
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 11

                        Rectangle {
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: Theme.radiusSmall
                            color: Qt.rgba(1, 1, 1, 0.06)

                            Text {
                                anchors.centerIn: parent
                                text: Theme.icon.desktop_windows
                                color: Theme.accent
                                font.family: Theme.iconFamily
                                font.pixelSize: 18
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "New recording"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.bold: true
                            }

                            Text {
                                text: "GPU-accelerated capture"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                            }
                        }

                        Item { Layout.fillWidth: true }

                        IconButton {
                            implicitWidth: 26
                            implicitHeight: 26
                            icon: Theme.icon.close
                            quiet: true
                            onClicked: root.controller.close()
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 9

                        SectionLabel { text: "Capture target" }

                        Rectangle {
                            id: singleMonitorCard
                            visible: root.controller.monitors.length === 1
                            Layout.fillWidth: true
                            implicitHeight: 72
                            radius: Theme.radiusSmall
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.13)
                            border.width: Theme.borderWidth
                            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Rectangle {
                                    implicitWidth: 44
                                    implicitHeight: 44
                                    radius: Math.max(2, Theme.radiusSmall - 1)
                                    color: Qt.rgba(1, 1, 1, 0.035)
                                    border.width: Theme.borderWidth
                                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)

                                    Text {
                                        anchors.centerIn: parent
                                        text: Theme.icon.desktop_windows
                                        color: Theme.accent
                                        font.family: Theme.iconFamily
                                        font.pixelSize: 20
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: root.controller.monitors.length === 1 ? root.controller.monitors[0].name : ""
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.controller.monitors.length === 1
                                            ? root.controller.monitors[0].make + (root.controller.monitors[0].model ? " " + root.controller.monitors[0].model : "")
                                                + "  ·  " + root.controller.monitors[0].width + "×" + root.controller.monitors[0].height
                                                + "  ·  " + root.controller.monitors[0].refreshRate.toFixed(0) + " Hz"
                                            : ""
                                        elide: Text.ElideRight
                                        color: Theme.textTertiary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                    }
                                }

                                Text {
                                    text: Theme.icon.check
                                    color: Theme.accent
                                    font.family: Theme.iconFamily
                                    font.pixelSize: 18
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.controller.monitors.length === 1) {
                                    root.controller.selectedMonitor = root.controller.monitors[0].name
                                }
                            }
                        }

                        GridLayout {
                            visible: root.controller.monitors.length > 1
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 10
                            rowSpacing: 10

                            Repeater {
                                model: root.controller.monitors

                                Rectangle {
                                    id: monitorCard
                                    required property var modelData
                                    readonly property bool selected: root.controller.selectedMonitor === modelData.name

                                    Layout.fillWidth: false
                                    Layout.preferredWidth: 203
                                    implicitHeight: 193
                                    radius: Theme.radiusSmall
                                    color: selected
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.13)
                                        : monitorMouse.containsMouse ? Theme.panelSurfaceHover : Theme.panelSurface
                                    border.width: Theme.borderWidth
                                    border.color: selected
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)
                                        : Theme.panelBorder

                                    Behavior on color {
                                        ColorAnimation { duration: Theme.animationFast }
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 9

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: width * 0.625
                                            radius: Math.max(2, Theme.radiusSmall - 1)
                                            color: Qt.rgba(1, 1, 1, 0.025)
                                            border.width: Theme.borderWidth
                                            border.color: monitorCard.selected
                                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4)
                                                : Theme.panelBorder

                                            Text {
                                                anchors.centerIn: parent
                                                text: Theme.icon.desktop_windows
                                                color: monitorCard.selected ? Theme.accent : Theme.textMuted
                                                font.family: Theme.iconFamily
                                                font.pixelSize: 18
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: monitorCard.modelData.make + (monitorCard.modelData.model ? " " + monitorCard.modelData.model : "")
                                            elide: Text.ElideRight
                                            color: monitorCard.selected ? Theme.textPrimary : Theme.textSecondary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.bold: true
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: monitorCard.modelData.name + "  ·  " + monitorCard.modelData.width + "×" + monitorCard.modelData.height
                                                + "  ·  " + monitorCard.modelData.refreshRate.toFixed(0) + " Hz"
                                            elide: Text.ElideRight
                                            color: monitorCard.selected ? Theme.accent : Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                        }
                                    }

                                    Rectangle {
                                        visible: monitorCard.selected
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        implicitWidth: 18
                                        implicitHeight: 18
                                        radius: 9
                                        color: Theme.accent

                                        Text {
                                            anchors.centerIn: parent
                                            text: Theme.icon.check
                                            color: Theme.base_
                                            font.family: Theme.iconFamily
                                            font.pixelSize: 13
                                            font.bold: true
                                        }
                                    }

                                    MouseArea {
                                        id: monitorMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.controller.selectedMonitor = monitorCard.modelData.name
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 9

                        SectionLabel { text: "Recording name" }

                        Controls.TextField {
                            id: titleInput
                            Layout.fillWidth: true
                            implicitHeight: 40
                            text: root.controller.draftTitle
                            placeholderText: "Recording title"
                            selectByMouse: true
                            color: Theme.textPrimary
                            placeholderTextColor: Theme.textMuted
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.base_
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMedium
                            leftPadding: 42
                            rightPadding: 12
                            onTextEdited: root.controller.draftTitle = text
                            background: Rectangle {
                                radius: Theme.radiusSmall
                                color: Qt.rgba(0, 0, 0, 0.22)
                                border.width: Theme.borderWidth
                                border.color: titleInput.activeFocus ? Theme.accent : Theme.panelBorder

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Theme.icon.screen_record
                                    color: Theme.textMuted
                                    font.family: Theme.iconFamily
                                    font.pixelSize: 15
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 9

                        SectionLabel { text: "Audio" }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            AudioToggle {
                                Layout.fillWidth: true
                                icon: root.controller.desktopAudio ? Theme.icon.volume_up : Theme.icon.volume_off
                                label: "Desktop audio"
                                on: root.controller.desktopAudio
                                accentColor: Theme.vol
                                onToggled: root.controller.desktopAudio = !root.controller.desktopAudio
                            }

                            AudioToggle {
                                Layout.fillWidth: true
                                icon: root.controller.microphone ? Theme.icon.mic : Theme.icon.mic_off
                                label: "Microphone"
                                on: root.controller.microphone
                                accentColor: Theme.mic
                                onToggled: root.controller.microphone = !root.controller.microphone
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.panelBorder
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            Text {
                                text: Theme.icon.folder
                                color: Theme.textMuted
                                font.family: Theme.iconFamily
                                font.pixelSize: 13
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.controller.recordingDirectory.indexOf(Quickshell.env("HOME")) === 0
                                    ? "~" + root.controller.recordingDirectory.slice(Quickshell.env("HOME").length)
                                    : root.controller.recordingDirectory
                                elide: Text.ElideMiddle
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            implicitWidth: startRow.implicitWidth + 30
                            implicitHeight: 40
                            radius: Theme.radiusSmall
                            color: startMouse.pressed ? Theme.mix(Theme.accent, Theme.textPrimary, 0.15) : Theme.accent

                            RowLayout {
                                id: startRow
                                anchors.centerIn: parent
                                spacing: 8

                                Rectangle {
                                    implicitWidth: 8
                                    implicitHeight: 8
                                    radius: 4
                                    color: Theme.base_
                                }

                                Text {
                                    text: root.controller.actionRunning ? "Starting…" : "Start recording"
                                    color: Theme.base_
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: startMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.controller.start()
                            }
                        }
                    }
                }

                RowLayout {
                    id: transportRow
                    visible: root.controller.active
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    Rectangle {
                        implicitWidth: 12
                        implicitHeight: 12
                        radius: 6
                        color: root.controller.paused ? Theme.textMuted : Theme.urgent

                        SequentialAnimation on scale {
                            running: root.controller.phase === "recording"
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.65; duration: 700; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutQuad }
                        }
                    }

                    Text {
                        text: root.controller.elapsedText
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: 27
                        font.bold: true
                    }

                    Rectangle {
                        implicitWidth: 1
                        implicitHeight: 24
                        color: Theme.panelBorder
                    }

                    IconButton {
                        implicitWidth: 42
                        implicitHeight: 42
                        icon: root.controller.paused ? Theme.icon.play_arrow : Theme.icon.pause
                        iconColor: root.controller.paused ? Theme.warning : Theme.textSecondary
                        iconSize: 23
                        quiet: true
                        onClicked: root.controller.togglePause()
                    }

                    IconButton {
                        implicitWidth: 42
                        implicitHeight: 42
                        icon: Theme.icon.stop
                        iconColor: Theme.urgent
                        iconSize: 23
                        quiet: true
                        onClicked: root.controller.finish()
                    }

                    IconButton {
                        implicitWidth: 42
                        implicitHeight: 42
                        icon: Theme.icon.delete
                        iconColor: Theme.textMuted
                        iconSize: 21
                        quiet: true
                        onClicked: root.controller.cancel()
                    }
                }

                ColumnLayout {
                    visible: root.controller.completed
                    Layout.preferredWidth: recorderPanel.implicitWidth - recorderPanel.padding * 2
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 11

                        Rectangle {
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: Theme.radiusSmall
                            color: Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.15)

                            Text {
                                anchors.centerIn: parent
                                text: Theme.icon.check
                                color: Theme.success
                                font.family: Theme.iconFamily
                                font.pixelSize: 18
                                font.bold: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "Recording saved"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Text {
                                text: "click the name to rename"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                            }
                        }

                        Item { Layout.fillWidth: true }

                        IconButton {
                            implicitWidth: 26
                            implicitHeight: 26
                            icon: Theme.icon.close
                            quiet: true
                            onClicked: root.controller.dismiss()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 2
                        Layout.rightMargin: 2
                        spacing: 14

                        Rectangle {
                            implicitWidth: 108
                            implicitHeight: 68
                            radius: Math.max(2, Theme.radiusSmall - 1)
                            color: playMouse.containsMouse
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                            border.width: Theme.borderWidth
                            border.color: Theme.panelBorder

                            Text {
                                anchors.centerIn: parent
                                text: Theme.icon.play_arrow
                                color: Theme.accent
                                font.family: Theme.iconFamily
                                font.pixelSize: 27
                            }

                            MouseArea {
                                id: playMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.controller.openRecording()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Controls.TextField {
                                id: renameInput
                                Layout.fillWidth: true
                                implicitHeight: 38
                                text: root.controller.renameTitle
                                selectByMouse: true
                                color: Theme.textPrimary
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.base_
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.bold: true
                                leftPadding: 6
                                rightPadding: 6
                                onTextEdited: root.controller.renameTitle = text
                                onActiveFocusChanged: root.controller.completionInteractionActive = activeFocus
                                onAccepted: root.controller.renameAndDismiss()
                                onEditingFinished: {
                                    if (text.trim() && text.trim() !== root.controller.outputFilename.replace(/\.mp4$/, "")) {
                                        root.controller.rename()
                                    }
                                }
                                background: Rectangle {
                                    radius: Math.max(2, Theme.radiusSmall - 1)
                                    color: renameInput.activeFocus ? Qt.rgba(0, 0, 0, 0.24) : "transparent"
                                    border.width: renameInput.activeFocus ? Theme.borderWidth : 0
                                    border.color: Theme.accent
                                }
                            }

                            RowLayout {
                                Layout.leftMargin: 6
                                spacing: 16

                                ColumnLayout {
                                    spacing: 2

                                    Text {
                                        text: root.controller.elapsedText
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    Text {
                                        text: "LENGTH"
                                        color: Theme.textMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.letterSpacing: 1
                                    }
                                }

                                ColumnLayout {
                                    spacing: 2

                                    Text {
                                        text: root.controller.outputSizeText
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    Text {
                                        text: "SIZE"
                                        color: Theme.textMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.letterSpacing: 1
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: root.controller.phase === "error"
                    Layout.preferredWidth: recorderPanel.implicitWidth - recorderPanel.padding * 2
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 11

                        Rectangle {
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: Theme.radiusSmall
                            color: Qt.rgba(Theme.urgent.r, Theme.urgent.g, Theme.urgent.b, 0.15)

                            Text {
                                anchors.centerIn: parent
                                text: Theme.icon.warning
                                color: Theme.urgent
                                font.family: Theme.iconFamily
                                font.pixelSize: 18
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "Capture interrupted"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.bold: true
                            }

                            Text {
                                text: "GPU Screen Recorder could not continue"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }

                        Item { Layout.fillWidth: true }

                        IconButton {
                            implicitWidth: 26
                            implicitHeight: 26
                            icon: Theme.icon.close
                            quiet: true
                            onClicked: root.controller.dismiss()
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.controller.errorMessage || "GPU Screen Recorder reported an unknown error."
                        wrapMode: Text.Wrap
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }
        }
    }
}
