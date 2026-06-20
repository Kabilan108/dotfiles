import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Scope {
    id: root

    property bool visible: false
    property var coordinator: null

    IpcHandler {
        target: "mixer"
        function toggle(): string {
            if (root.coordinator) return root.coordinator.togglePanel(root)
            root.visible = !root.visible
            return root.visible ? "open" : "closed"
        }

        function open(): string {
            if (root.coordinator) return root.coordinator.panelAction("audio", "open")
            root.visible = true
            return "open"
        }

        function close(): string {
            root.visible = false
            return "closed"
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
                left: true
                right: true
                bottom: true
            }
            margins {
                top: Theme.barHeight + Theme.screenMargin + Theme.panelGap
            }
            exclusiveZone: 0
            focusable: false
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onClicked: root.visible = false
            }

            MouseArea {
                anchors.fill: content
                onClicked: {}
            }

            PopupPanel {
                id: content
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.rightMargin: Theme.screenMargin
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
        }
    }
}
