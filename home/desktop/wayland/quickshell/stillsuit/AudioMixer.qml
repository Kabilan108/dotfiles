import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Scope {
    id: root

    property bool visible: false
    property var coordinator: null
    property var outputs: []
    property var inputs: []
    readonly property string outputTitle: {
        const output = activeDevice(outputs)
        if (output) return output.title
        return "Output"
    }
    readonly property string outputSubtitle: {
        const output = activeDevice(outputs)
        if (output) return output.subtitle
        return Pipewire.defaultAudioSink?.description ?? ""
    }
    readonly property string inputTitle: {
        const input = activeDevice(inputs)
        if (input) return input.title
        return "Input"
    }
    readonly property string inputSubtitle: {
        const input = activeDevice(inputs)
        if (input) return input.subtitle
        return Pipewire.defaultAudioSource?.description ?? ""
    }

    function refreshDevices() {
        if (!sinkProc.running) sinkProc.running = true
        if (!sourceProc.running) sourceProc.running = true
    }

    function cleanLabel(raw, fallback) {
        const text = String(raw || "").trim()
        return text !== "" ? text : fallback
    }

    function portKind(value) {
        const text = String(value || "").toLowerCase()
        if (text.includes("headphone") || text.includes("headset") || text.includes("bluetooth")) return "headphones"
        if (text.includes("hdmi") || text.includes("displayport")) return "display"
        if (text.includes("speaker")) return "speakers"
        return "default"
    }

    function devicePriority(kind) {
        if (kind === "headphones") return 0
        if (kind === "speakers") return 1
        if (kind === "display") return 2
        return 3
    }

    function activeDevice(devices) {
        for (const device of devices) {
            if (device.active) return device
        }
        return null
    }

    function iconFor(kind) {
        if (kind === "display") return Theme.icon.screen_record
        if (kind === "headphones") return Theme.icon.bluetooth_connected
        return Theme.icon.volume_up
    }

    function compactDescription(item) {
        return cleanLabel(item.description, item.nick || item.name)
            .replace(/^Monitor of /i, "")
            .replace(/\s+Analog Stereo$/i, "")
            .trim()
    }

    function titleFor(item, kind, isSource) {
        if (isSource) return "Microphone"
        if (kind === "headphones") return "Headphones"
        if (kind === "speakers") return "Speakers"
        if (kind === "display") {
            const trimmed = compactDescription(item)
            return trimmed !== "" ? trimmed : "HDMI Output"
        }
        return compactDescription(item)
    }

    function subtitleFor(item, kind, isSource) {
        const port = String(item.active_port || "")
        if (isSource) {
            if (port.includes("bluetooth")) return "bluetooth mic"
            if (port.includes("headset")) return "headset mic"
            if (port.includes("mic")) return "analog input"
            return item.nick || compactDescription(item)
        }
        if (kind === "headphones" && port.includes("bluetooth")) return "bluetooth"
        if (kind === "display") return "hdmi"
        if (port.includes("speaker")) return "built-in speaker"
        if (port.includes("headphone")) return "analog output"
        if (item.nick) return item.nick
        return compactDescription(item)
    }

    function parseDevices(raw, isSource) {
        let parsed = []
        try {
            parsed = JSON.parse(String(raw || "[]"))
        } catch (error) {
            console.warn("stillsuit audio: failed to parse device list:", error)
            return []
        }

        const defaultName = String(isSource ? Pipewire.defaultAudioSource?.name ?? "" : Pipewire.defaultAudioSink?.name ?? "")
        const next = []

        for (const item of parsed) {
            const name = String(item.name || "")
            if (!name) continue
            if (isSource && name.endsWith(".monitor")) continue

            const kind = portKind(item.active_port || item.description || name)
            next.push({
                name: name,
                icon: iconFor(kind),
                kind: kind,
                title: titleFor(item, kind, isSource),
                subtitle: subtitleFor(item, kind, isSource),
                active: name === defaultName,
                priority: devicePriority(kind)
            })
        }

        next.sort((a, b) => {
            if (a.priority !== b.priority) return a.priority - b.priority
            const title = a.title.localeCompare(b.title)
            if (title !== 0) return title
            const subtitle = a.subtitle.localeCompare(b.subtitle)
            if (subtitle !== 0) return subtitle
            return a.name.localeCompare(b.name)
        })
        return next
    }

    function parseOutputs(raw) {
        outputs = parseDevices(raw, false)
    }

    function parseInputs(raw) {
        inputs = parseDevices(raw, true)
    }

    function setDefaultSink(name) {
        if (!name || actionProc.running) return
        actionProc.command = ["pactl", "set-default-sink", name]
        actionProc.running = true
    }

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

    onVisibleChanged: if (visible) refreshDevices()
    Component.onCompleted: refreshDevices()

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    Process {
        id: sinkProc
        command: ["bash", "-lc", "pactl -f json list sinks 2>/dev/null || printf '[]'"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseOutputs(text)
        }
    }

    Process {
        id: sourceProc
        command: ["bash", "-lc", "pactl -f json list sources 2>/dev/null || printf '[]'"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseInputs(text)
        }
    }

    Process {
        id: actionProc
        onExited: root.refreshDevices()
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
                implicitWidth: 360
                padding: 16

                Item {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(520, panelFlick.contentHeight)

                    Flickable {
                        id: panelFlick
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: panelBody.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: panelBody
                            width: panelFlick.width
                            spacing: 14

                            NowPlaying {
                                id: nowPlaying
                                width: parent.width
                            }

                            Rectangle {
                                width: parent.width
                                implicitHeight: 1
                                color: Theme.panelBorder
                                visible: nowPlaying.visible
                            }

                            Column {
                                width: parent.width
                                spacing: 13

                                MixerSlider {
                                    node: Pipewire.defaultAudioSink
                                    width: parent.width
                                    title: "Output · " + root.outputTitle
                                    subtitle: ""
                                    framed: false
                                    visible: Pipewire.defaultAudioSink !== null
                                }

                                MixerSlider {
                                    node: Pipewire.defaultAudioSource
                                    width: parent.width
                                    title: "Input · " + root.inputTitle
                                    subtitle: ""
                                    framed: false
                                    visible: Pipewire.defaultAudioSource !== null
                                }
                            }

                            Rectangle {
                                width: parent.width
                                implicitHeight: 1
                                color: Theme.panelBorder
                                visible: outputRepeater.count > 0
                            }

                            Column {
                                width: parent.width
                                spacing: 2
                                visible: outputRepeater.count > 0

                                SectionLabel {
                                    text: "Output Device"
                                    bottomPadding: 12
                                }

                                Repeater {
                                    id: outputRepeater
                                    model: root.outputs

                                    AudioDeviceRow {
                                        required property var modelData

                                        width: parent.width
                                        icon: modelData.icon
                                        title: modelData.title
                                        subtitle: modelData.subtitle
                                        active: modelData.active
                                        onClicked: root.setDefaultSink(modelData.name)
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
