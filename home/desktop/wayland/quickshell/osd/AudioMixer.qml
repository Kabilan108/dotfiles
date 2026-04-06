import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Scope {
    id: root

    property bool visible: false

    IpcHandler {
        target: "mixer"
        function toggle(): void {
            root.visible = !root.visible
        }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    PwNodeLinkTracker {
        id: sinkLinks
        node: Pipewire.defaultAudioSink
    }

    LazyLoader {
        active: root.visible

        PanelWindow {
            anchors {
                top: true
                right: true
            }
            margins {
                top: 40
                right: 12
            }
            exclusiveZone: 0
            focusable: true
            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight
            color: "transparent"

            PopupPanel {
                id: content
                implicitWidth: 340

                NowPlaying {
                    id: nowPlaying
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.surface0
                    visible: nowPlaying.visible
                }

                // Output section
                Text {
                    text: "Output"
                    color: Theme.dimText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }

                MixerSlider {
                    node: Pipewire.defaultAudioSink
                    Layout.fillWidth: true
                    visible: Pipewire.defaultAudioSink !== null
                }

                // Separator before apps (only if apps exist)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.surface0
                    visible: appRepeater.count > 0
                }

                Text {
                    text: "Apps"
                    color: Theme.dimText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    visible: appRepeater.count > 0
                }

                Repeater {
                    id: appRepeater
                    model: sinkLinks.linkGroups

                    MixerSlider {
                        required property PwLinkGroup modelData
                        required property int index

                        node: modelData.source
                        compact: true
                        Layout.fillWidth: true

                        visible: {
                            for (let i = 0; i < index; i++) {
                                const item = appRepeater.itemAt(i)
                                if (item && item.appName === appName) return false
                            }
                            return true
                        }

                        syncNodes: {
                            void(appRepeater.count)
                            const nodes = []
                            for (let i = 0; i < appRepeater.count; i++) {
                                if (i === index) continue
                                const item = appRepeater.itemAt(i)
                                if (item && item.appName === appName)
                                    nodes.push(item.node)
                            }
                            return nodes
                        }
                    }
                }

                // Separator before input
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.surface0
                }

                Text {
                    text: "Input"
                    color: Theme.dimText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }

                MixerSlider {
                    node: Pipewire.defaultAudioSource
                    Layout.fillWidth: true
                    visible: Pipewire.defaultAudioSource !== null
                }
            }

            // Click outside to close
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: root.visible = false
                enabled: false
            }
        }
    }
}
