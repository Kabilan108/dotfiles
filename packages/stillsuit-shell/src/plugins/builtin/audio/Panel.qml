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

    component RoundControl: Ui.ShellAction {
        id: control

        required property var theme
        property string iconName: ""
        property string label: ""
        property bool active: false
        property bool accentIcon: false
        property bool prominent: false

        signal clicked()

        accessibleFallback: iconName.replace(/-/g, " ")
        implicitWidth: prominent ? 40 : 34
        implicitHeight: implicitWidth
        onActivated: clicked()

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: !control.enabled
                ? control.theme.component.control.disabled
                : control.active
                    ? control.theme.component.control.active
                    : control.pressed
                        ? control.theme.component.control.pressed
                        : control.hovered
                            ? control.theme.component.control.hover
                            : control.theme.component.control.background
            border.width: control.active ? 0 : 1
            border.color: control.theme.component.control.outline
            opacity: control.enabled ? 1 : 0.74
        }

        Ui.ShellIcon {
            anchors.centerIn: parent
            theme: control.theme
            name: control.iconName
            sizeRole: control.prominent ? "medium" : "small"
            role: control.active
                ? "on-accent"
                : control.accentIcon
                    ? "accent"
                    : "primary"
        }

        Ui.ShellText {
            visible: control.label !== ""
            anchors {
                right: parent.right
                bottom: parent.bottom
                rightMargin: 3
                bottomMargin: 1
            }
            theme: control.theme
            text: control.label
            sizeRole: "caption"
            role: control.active ? "on-accent" : "primary"
        }
    }

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
            id: panelSurface

            anchors {
                top: parent.top
                right: parent.right
                topMargin: root.context.theme.metrics.barHeight
                    + root.context.theme.metrics.spaceUnit
                rightMargin: root.context.theme.metrics.spaceUnit
            }
            width: root.context.theme.metrics.panelWidth
            height: Math.min(content.implicitHeight
                    + root.context.theme.metrics.panelPadding * 2,
                parent.height - anchors.topMargin
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

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: root.context.theme.metrics.spaceUnit

                        Ui.ShellText {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            text: "Audio"
                            sizeRole: "heading"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: root.context.theme.semantic.outline.subtle
                        }
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

                                Ui.ShellText {
                                    Layout.fillWidth: true
                                    theme: root.context.theme
                                    text: root.media ? root.media.playerName : ""
                                    sizeRole: "caption"
                                    role: "muted"
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        ColumnLayout {
                            visible: root.media
                                && root.media.playerSummaries.length > 1
                            Layout.fillWidth: true
                            spacing: root.context.theme.metrics.spaceUnit

                            Ui.ShellSectionLabel {
                                Layout.fillWidth: true
                                theme: root.context.theme
                                text: "Sources"
                            }

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
                        }

                        Ui.ShellSlider {
                            visible: root.media && root.media.lengthSupported
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            theme: root.context.theme
                            label: root.formatTime(root.media ? root.media.position : 0)
                            accessibleName: "Playback position"
                            from: 0
                            to: root.media ? Math.max(1, root.media.length) : 1
                            value: root.media ? root.media.position : 0
                            stepSize: 1
                            decimals: 0
                            valueText: root.media
                                ? root.formatTime(root.media.length)
                                : ""
                            trackBottomMargin: 6
                            enabled: root.media && root.media.canSeek
                            onMoved: function(value) { root.media.seekTo(value) }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: root.context.theme.metrics.spaceUnit * 2

                            RoundControl {
                                visible: root.media && root.media.shuffleSupported
                                theme: root.context.theme
                                iconName: "shuffle"
                                active: root.media && root.media.shuffle
                                accessibleName: root.media && root.media.shuffle
                                    ? "Disable shuffle"
                                    : "Enable shuffle"
                                onClicked: root.media.toggleShuffle()
                            }

                            RoundControl {
                                theme: root.context.theme
                                iconName: "skip-previous"
                                enabled: root.media && root.media.canGoPrevious
                                accessibleName: "Previous track"
                                onClicked: root.media.previous()
                            }

                            RoundControl {
                                theme: root.context.theme
                                iconName: "replay-10"
                                enabled: root.media && root.media.canSeek
                                accessibleName: "Seek back 10 seconds"
                                onClicked: root.media.seekBy(-10)
                            }

                            RoundControl {
                                theme: root.context.theme
                                iconName: root.media && root.media.isPlaying ? "pause" : "play"
                                active: true
                                prominent: true
                                enabled: root.media && root.media.canTogglePlaying
                                accessibleName: root.media && root.media.isPlaying
                                    ? "Pause"
                                    : "Play"
                                onClicked: root.media.togglePlaying()
                            }

                            RoundControl {
                                theme: root.context.theme
                                iconName: "forward-10"
                                enabled: root.media && root.media.canSeek
                                accessibleName: "Seek forward 10 seconds"
                                onClicked: root.media.seekBy(10)
                            }

                            RoundControl {
                                theme: root.context.theme
                                iconName: "skip-next"
                                enabled: root.media && root.media.canGoNext
                                accessibleName: "Next track"
                                onClicked: root.media.next()
                            }

                            RoundControl {
                                visible: root.media && root.media.repeatSupported
                                theme: root.context.theme
                                iconName: "repeat"
                                label: root.media && root.media.repeatMode === "track" ? "1" : ""
                                active: root.media && root.media.repeatMode !== "none"
                                accessibleName: "Repeat "
                                    + (root.media ? root.media.repeatMode : "none")
                                onClicked: root.media.cycleRepeat()
                            }
                        }
                    }

                    Ui.ShellSectionLabel {
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: "Levels"
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
                        spacing: root.context.theme.metrics.spaceUnit

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.context.theme.metrics.spaceUnit * 2

                            RoundControl {
                                theme: root.context.theme
                                iconName: !root.service || root.service.muted
                                    ? "volume-mute"
                                    : root.service.volume < 0.5
                                        ? "volume-down"
                                        : "volume-up"
                                accentIcon: root.service
                                    && !root.service.muted
                                enabled: root.service && root.service.available
                                accessibleName: root.service && root.service.muted
                                    ? "Unmute output"
                                    : "Mute output"
                                onClicked: root.service.toggleMuted()
                            }

                            Ui.ShellSlider {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                theme: root.context.theme
                                label: root.service
                                    ? root.service.outputName
                                    : "Output"
                                accessibleName: "Output volume"
                                from: 0
                                to: 100
                                value: root.service
                                    ? Math.min(100, root.service.volume * 100)
                                    : 0
                                stepSize: 1
                                decimals: 0
                                suffix: "%"
                                trackHeight: 7
                                trackBottomMargin: 6
                                enabled: root.service && root.service.available
                                onMoved: function(value) {
                                    root.service.setVolume(value / 100)
                                }
                            }
                        }

                        RowLayout {
                            visible: root.service
                                && root.service.microphoneAvailable
                            Layout.fillWidth: true
                            spacing: root.context.theme.metrics.spaceUnit * 2

                            RoundControl {
                                theme: root.context.theme
                                iconName: root.service && root.service.inputMuted
                                    ? "volume-mute"
                                    : "microphone"
                                accentIcon: root.service
                                    && !root.service.inputMuted
                                enabled: root.service
                                    && root.service.microphoneAvailable
                                accessibleName: root.service
                                        && root.service.inputMuted
                                    ? "Unmute microphone"
                                    : "Mute microphone"
                                onClicked: root.service.toggleInputMuted()
                            }

                            Ui.ShellSlider {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                theme: root.context.theme
                                label: root.service
                                    ? root.service.inputName
                                    : "Microphone"
                                accessibleName: "Microphone level"
                                from: 0
                                to: 100
                                value: root.service
                                    ? Math.min(100,
                                        root.service.inputVolume * 100)
                                    : 0
                                stepSize: 1
                                decimals: 0
                                suffix: "%"
                                trackHeight: 7
                                trackBottomMargin: 6
                                enabled: root.service
                                    && root.service.microphoneAvailable
                                onMoved: function(value) {
                                    root.service.setInputVolume(value / 100)
                                }
                            }
                        }

                        Ui.ShellStateView {
                            visible: root.service
                                && !root.service.microphoneAvailable
                            Layout.fillWidth: true
                            Layout.preferredHeight: 88
                            theme: root.context.theme
                            mode: "empty"
                            title: "Microphone unavailable"
                            iconName: "microphone"
                        }

                        Ui.ShellStatus {
                            visible: root.service
                                && root.service.errorMessage !== ""
                            Layout.alignment: Qt.AlignHCenter
                            theme: root.context.theme
                            status: "danger"
                            label: root.service
                                ? root.service.errorMessage
                                : ""
                        }
                    }

                    Ui.ShellSectionLabel {
                        visible: root.service && root.service.available
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: "Output devices"
                    }

                    ColumnLayout {
                        visible: root.service && root.service.available
                        Layout.fillWidth: true
                        spacing: 2

                        Repeater {
                            model: root.service ? root.service.outputs : []

                            Ui.ShellRow {
                                required property var modelData

                                Layout.fillWidth: true
                                theme: root.context.theme
                                minimumHeight: 30
                                label: modelData.description
                                iconName: modelData.iconName || "audio"
                                selected: Boolean(modelData.active)
                                trailingIconName: modelData.active ? "check" : ""
                                enabled: root.service
                                    && !root.service.outputActionBusy
                                busy: root.service
                                    && root.service.outputActionBusy
                                    && !modelData.active
                                accessibleName: "Use "
                                    + modelData.description
                                    + " for audio output"
                                onClicked: root.service.selectOutput(modelData.name)
                            }
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
        var hours = Math.floor(safe / 3600)
        var minutes = Math.floor(safe % 3600 / 60)
        var remainder = Math.floor(safe % 60)
        if (hours > 0)
            return hours + ":" + String(minutes).padStart(2, "0")
                + ":" + String(remainder).padStart(2, "0")
        return minutes + ":" + String(remainder).padStart(2, "0")
    }
}
