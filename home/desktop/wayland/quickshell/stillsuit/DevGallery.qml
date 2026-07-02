import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "ui" as Ui

Scope {
    id: root

    property bool visible: false

    readonly property int dictationBars: 23
    property string dictationState: "recording"
    property var dictationLevels: []
    property real dictationElapsedMs: 0
    property string dictationDuration: "0:00"

    function seedDictationLevels() {
        const next = []
        for (let i = 0; i < dictationBars; i++) next.push(0)
        dictationLevels = next
    }

    function formatDuration(ms) {
        const totalSeconds = Math.floor(Math.max(ms, 0) / 1000)
        return Math.floor(totalSeconds / 60) + ":" + (totalSeconds % 60 < 10 ? "0" : "") + (totalSeconds % 60)
    }

    Component.onCompleted: seedDictationLevels()

    onDictationStateChanged: {
        if (dictationState === "recording") dictationElapsedMs = 0
        else if (dictationState === "error") dictationDuration = ""
    }

    Timer {
        interval: 33
        repeat: true
        running: root.visible && root.dictationState === "recording"
        property real t: 0
        onTriggered: {
            t += 0.033
            root.dictationElapsedMs += 33
            root.dictationDuration = root.formatDuration(root.dictationElapsedMs)
            const phrase = Math.pow((Math.sin(t * 1.7) * 0.5) + 0.5, 1.7)
            const syllable = Math.pow((Math.sin(t * 11) * 0.5) + 0.5, 2.2)
            const consonant = Math.pow((Math.sin(t * 29) * 0.5) + 0.5, 8)
            const sample = Math.min((phrase * 0.7) + (syllable * 0.28) + (consonant * 0.28), 0.92)
            const next = root.dictationLevels.slice()
            next.push(sample)
            while (next.length > root.dictationBars) next.shift()
            root.dictationLevels = next
        }
    }

    readonly property var normalNotification: ({
        appName: "stillsuit",
        appIcon: "",
        image: "",
        summary: "Notification redesign",
        body: "This card is rendered by the same component used for live notification popups.",
        urgency: NotificationUrgency.Normal,
        actions: [
            { text: "Open", invoke: function() {} },
            { text: "Dismiss", invoke: function() {} }
        ]
    })

    readonly property var criticalNotification: ({
        appName: "battery",
        appIcon: "",
        image: "",
        summary: "Battery critically low",
        body: "Critical notifications can bypass DND according to the Nix-owned policy file.",
        urgency: NotificationUrgency.Critical,
        actions: []
    })

    IpcHandler {
        target: "gallery"

        function toggle(): string {
            root.visible = !root.visible
            return root.visible ? "open" : "closed"
        }

        function open(): string {
            root.visible = true
            return "open"
        }

        function close(): string {
            root.visible = false
            return "closed"
        }

        function show(): string {
            root.visible = true
            return "open"
        }

        function hide(): string {
            root.visible = false
            return "closed"
        }
    }

    LazyLoader {
        active: true

        PanelWindow {
            visible: root.visible
            anchors {
                top: true
                right: true
            }
            margins {
                top: 72
                right: Theme.screenMargin
            }
            exclusiveZone: 0
            focusable: true
            implicitWidth: panel.implicitWidth
            implicitHeight: panel.implicitHeight
            color: "transparent"

            PopupPanel {
                id: panel
                implicitWidth: 520
                padding: 18

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Stillsuit Gallery"
                            color: Theme.textPrimary
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontSizeLarge
                            font.bold: true
                        }

                        Text {
                            text: "Live components for tuning the visual system"
                            color: Theme.textTertiary
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    Ui.StButton {
                        icon: "󰅖"
                        subtle: true
                        onClicked: root.visible = false
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(content.implicitHeight, 680)
                    contentHeight: content.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: content
                        width: parent.width
                        spacing: 14

                        Ui.StSectionHeader {
                            label: "Controls"
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Ui.StButton {
                                text: "Primary"
                                icon: "󰄬"
                                active: true
                            }

                            Ui.StButton {
                                text: "Quiet"
                                icon: "󰂚"
                            }

                            Ui.StButton {
                                text: "Danger"
                                icon: "󰅖"
                                danger: true
                            }

                            Ui.StPill {
                                text: "DND"
                                icon: "󰂛"
                                active: true
                                accentColor: Theme.warning
                            }
                        }

                        Ui.StSectionHeader {
                            label: "Notification popup"
                            Layout.fillWidth: true
                        }

                        NotificationCard {
                            notification: root.normalNotification
                            inline: false
                        }

                        Ui.StSectionHeader {
                            label: "Notification center row"
                            Layout.fillWidth: true
                        }

                        NotificationCard {
                            notification: root.criticalNotification
                            inline: true
                            Layout.fillWidth: true
                        }

                        Ui.StSectionHeader {
                            label: "Dictation OSD"
                            Layout.fillWidth: true
                        }

                        DictationPill {
                            Layout.alignment: Qt.AlignHCenter
                            mode: root.dictationState
                            levels: root.dictationLevels
                            durationText: root.dictationDuration
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8

                            Repeater {
                                model: ["recording", "transcribing", "typing", "error"]

                                Ui.StButton {
                                    required property string modelData
                                    text: modelData
                                    active: root.dictationState === modelData
                                    onClicked: root.dictationState = modelData
                                }
                            }
                        }

                        Ui.StSectionHeader {
                            label: "Panel surface"
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 92
                            radius: Theme.radiusMedium
                            color: Theme.panelBgSoft
                            border.width: Theme.borderWidth
                            border.color: Theme.panelBorder

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                Text {
                                    text: "󰕾"
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeIconLarge
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Text {
                                        text: "Shared surface language"
                                        color: Theme.textPrimary
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: Theme.fontSizeTitle
                                        font.bold: true
                                    }

                                    Text {
                                        text: "This is intentionally more Omarchy-like than the old shell so it can be pared back visually."
                                        color: Theme.textTertiary
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
