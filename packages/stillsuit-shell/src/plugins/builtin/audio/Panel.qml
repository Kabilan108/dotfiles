import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../ui" as Ui

Scope {
    id: root

    required property var context
    required property var service
    required property var screen
    required property string outputId
    readonly property var media: service ? service.media : null
    readonly property var panelWindow: window
    property bool opened: false

    PanelWindow {
        id: window

        screen: root.screen
        visible: root.opened
        color: "transparent"
        exclusiveZone: 0
        focusable: true
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        mask: Region {
            item: dismissArea
        }

        MouseArea {
            id: dismissArea
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                topMargin: root.context.theme.metrics.barHeight
            }
            acceptedButtons: Qt.AllButtons
            onClicked: root.context.actions.surfaceClose("stillsuit.audio")
        }

        Ui.ShellSurface {
            anchors {
                top: parent.top
                right: parent.right
                topMargin: root.context.theme.metrics.barHeight
                    + root.context.theme.metrics.spaceUnit
                rightMargin: root.context.theme.metrics.spaceUnit
            }
            width: root.context.theme.metrics.panelWidth
            height: Math.min(680, parent.height - anchors.topMargin
                - root.context.theme.metrics.spaceUnit)
            theme: root.context.theme
            kind: "panel"

            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) { mouse.accepted = true }
            }

            Flickable {
                anchors {
                    fill: parent
                    margins: root.context.theme.metrics.panelPadding
                }
                contentWidth: width
                contentHeight: content.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: content

                    width: parent.width
                    spacing: root.context.theme.metrics.spaceUnit * 3

                    Ui.ShellText {
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: "Audio and media"
                        sizeRole: "heading"
                    }

                    Ui.ShellSectionLabel {
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: "Now playing"
                    }

                    Ui.ShellStateView {
                        visible: !root.media || root.media.state !== "ready"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 104
                        theme: root.context.theme
                        mode: root.media && root.media.state === "error"
                            ? "error"
                            : "empty"
                        title: root.media && root.media.state === "error"
                            ? "Media controls unavailable"
                            : "Nothing playing"
                        message: root.media && root.media.errorMessage
                            ? root.media.errorMessage
                            : "Start a compatible media player to show controls."
                        iconName: "play"
                    }

                    ColumnLayout {
                        visible: root.media && root.media.state === "ready"
                        Layout.fillWidth: true
                        spacing: root.context.theme.metrics.spaceUnit * 2

                        Repeater {
                            model: root.media ? root.media.playerSummaries : []

                            Ui.ShellRow {
                                required property var modelData

                                Layout.fillWidth: true
                                theme: root.context.theme
                                label: modelData.name
                                description: modelData.title
                                iconName: modelData.playing ? "play" : "audio"
                                selected: modelData.selected
                                trailingText: modelData.playing ? "PLAYING" : ""
                                accessibleName: "Select " + modelData.name
                                onClicked: root.media.selectPlayer(modelData.id)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.context.theme.metrics.spaceUnit * 3

                            Ui.ShellSurface {
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 64
                                theme: root.context.theme
                                kind: "raised"

                                Image {
                                    id: albumArt

                                    anchors.fill: parent
                                    source: root.media ? root.media.artUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready
                                }

                                Ui.ShellIcon {
                                    visible: albumArt.status !== Image.Ready
                                    anchors.centerIn: parent
                                    theme: root.context.theme
                                    name: "audio"
                                    sizeRole: "large"
                                    role: "muted"
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: root.context.theme.metrics.spaceUnit

                                Ui.ShellText {
                                    Layout.fillWidth: true
                                    theme: root.context.theme
                                    text: root.media ? root.media.title : ""
                                    sizeRole: "label"
                                    elide: Text.ElideRight
                                }

                                Ui.ShellText {
                                    Layout.fillWidth: true
                                    theme: root.context.theme
                                    text: root.media ? root.media.artist : ""
                                    role: "secondary"
                                    elide: Text.ElideRight
                                }

                                Ui.ShellText {
                                    visible: root.media && root.media.album !== ""
                                    Layout.fillWidth: true
                                    theme: root.context.theme
                                    text: root.media ? root.media.album : ""
                                    sizeRole: "caption"
                                    role: "muted"
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Ui.ShellSlider {
                            visible: root.media && root.media.lengthSupported
                            Layout.fillWidth: true
                            theme: root.context.theme
                            label: root.formatTime(root.media ? root.media.position : 0)
                            accessibleName: "Playback position"
                            from: 0
                            to: root.media ? Math.max(1, root.media.length) : 1
                            value: root.media ? root.media.position : 0
                            stepSize: 1
                            decimals: 0
                            suffix: root.media
                                ? " / " + root.formatTime(root.media.length)
                                : ""
                            enabled: root.media && root.media.canSeek
                            onMoved: function(value) { root.media.seekTo(value) }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: root.context.theme.metrics.spaceUnit * 2

                            Ui.ShellButton {
                                visible: root.media && root.media.shuffleSupported
                                theme: root.context.theme
                                iconName: "shuffle"
                                active: root.media && root.media.shuffle
                                compact: true
                                accessibleName: root.media && root.media.shuffle
                                    ? "Disable shuffle"
                                    : "Enable shuffle"
                                onClicked: root.media.toggleShuffle()
                            }

                            Ui.ShellButton {
                                theme: root.context.theme
                                iconName: "skip-previous"
                                compact: true
                                enabled: root.media && root.media.canGoPrevious
                                accessibleName: "Previous track"
                                onClicked: root.media.previous()
                            }

                            Ui.ShellButton {
                                theme: root.context.theme
                                iconName: root.media && root.media.isPlaying ? "pause" : "play"
                                active: true
                                enabled: root.media && root.media.canTogglePlaying
                                accessibleName: root.media && root.media.isPlaying
                                    ? "Pause"
                                    : "Play"
                                onClicked: root.media.togglePlaying()
                            }

                            Ui.ShellButton {
                                theme: root.context.theme
                                iconName: "skip-next"
                                compact: true
                                enabled: root.media && root.media.canGoNext
                                accessibleName: "Next track"
                                onClicked: root.media.next()
                            }

                            Ui.ShellButton {
                                visible: root.media && root.media.repeatSupported
                                theme: root.context.theme
                                iconName: "repeat"
                                label: root.media && root.media.repeatMode === "track" ? "1" : ""
                                active: root.media && root.media.repeatMode !== "none"
                                compact: true
                                accessibleName: "Repeat "
                                    + (root.media ? root.media.repeatMode : "none")
                                onClicked: root.media.cycleRepeat()
                            }
                        }
                    }

                    Ui.ShellSectionLabel {
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: "Output"
                    }

                    Ui.ShellStateView {
                        visible: !root.service || !root.service.available
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        theme: root.context.theme
                        mode: "error"
                        title: "PipeWire unavailable"
                        message: "Output and microphone controls are disabled."
                        iconName: "volume-mute"
                    }

                    ColumnLayout {
                        visible: root.service && root.service.available
                        Layout.fillWidth: true
                        spacing: root.context.theme.metrics.spaceUnit * 2

                        Ui.ShellSlider {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            label: root.service ? root.service.outputName : "Output"
                            accessibleName: "Output volume"
                            from: 0
                            to: 100
                            value: root.service
                                ? Math.min(100, root.service.volume * 100)
                                : 0
                            stepSize: 1
                            decimals: 0
                            suffix: "%"
                            enabled: root.service && root.service.available
                            onMoved: function(value) { root.service.setVolume(value / 100) }
                        }

                        Ui.ShellToggle {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            label: "Mute output"
                            description: root.service ? root.service.outputName : ""
                            checked: root.service && root.service.muted
                            enabled: root.service && root.service.available
                            onToggled: root.service.toggleMuted()
                        }

                        Ui.ShellStatus {
                            visible: root.service && root.service.errorMessage !== ""
                            Layout.alignment: Qt.AlignHCenter
                            theme: root.context.theme
                            status: "danger"
                            label: root.service ? root.service.errorMessage : ""
                        }

                        Repeater {
                            model: root.service ? root.service.outputs : []

                            Ui.ShellRow {
                                required property var modelData

                                Layout.fillWidth: true
                                theme: root.context.theme
                                label: modelData.description
                                iconName: modelData.iconName || "audio"
                                selected: Boolean(modelData.active)
                                trailingIconName: modelData.active ? "check" : ""
                                enabled: root.service && !root.service.outputActionBusy
                                busy: root.service && root.service.outputActionBusy
                                    && !modelData.active
                                accessibleName: "Use " + modelData.description
                                    + " for audio output"
                                onClicked: root.service.selectOutput(modelData.name)
                            }
                        }
                    }

                    Ui.ShellSectionLabel {
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: "Microphone"
                    }

                    Ui.ShellStateView {
                        visible: root.service && !root.service.microphoneAvailable
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        theme: root.context.theme
                        mode: "empty"
                        title: "Microphone unavailable"
                        iconName: "microphone"
                    }

                    ColumnLayout {
                        visible: root.service && root.service.microphoneAvailable
                        Layout.fillWidth: true
                        spacing: root.context.theme.metrics.spaceUnit * 2

                        Ui.ShellSlider {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            label: root.service ? root.service.inputName : "Microphone"
                            accessibleName: "Microphone level"
                            from: 0
                            to: 100
                            value: root.service
                                ? Math.min(100, root.service.inputVolume * 100)
                                : 0
                            stepSize: 1
                            decimals: 0
                            suffix: "%"
                            enabled: root.service && root.service.microphoneAvailable
                            onMoved: function(value) {
                                root.service.setInputVolume(value / 100)
                            }
                        }

                        Ui.ShellToggle {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            label: "Mute microphone"
                            description: root.service ? root.service.inputName : ""
                            checked: root.service && root.service.inputMuted
                            enabled: root.service && root.service.microphoneAvailable
                            onToggled: root.service.toggleInputMuted()
                        }
                    }
                }
            }
        }
    }

    function open(payloadJson) {
        opened = true
        if (service)
            service.refreshOutputs()
    }

    function close() {
        opened = false
    }

    function formatTime(seconds) {
        var safe = Math.max(0, Number(seconds || 0))
        var minutes = Math.floor(safe / 60)
        var remainder = Math.floor(safe % 60)
        return minutes + ":" + String(remainder).padStart(2, "0")
    }
}
