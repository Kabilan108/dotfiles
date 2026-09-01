import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

QtObject {
    id: root

    required property var context
    property var model: null
    property bool forceUnavailable: false
    property var systemOutputs: []
    property string errorMessage: ""
    property bool outputActionBusy: false
    property bool outputRefreshBusy: false
    property bool outputListParsed: false

    readonly property string apiVersion: "1"
    readonly property var sink: model ? model.sink || null : Pipewire.defaultAudioSink
    readonly property var source: model ? model.source || null : Pipewire.defaultAudioSource
    readonly property var outputs: model ? model.outputs || [] : _activeOutputs()
    readonly property bool available: !forceUnavailable
        && (model !== null || sink !== null)
    readonly property bool microphoneAvailable: !forceUnavailable
        && (model !== null || source !== null)
    readonly property real volume: _clamp(_audioValue(sink, "volume",
        model ? model.volume : 0))
    readonly property bool muted: _audioBool(sink, "muted",
        model && model.muted)
    readonly property real inputVolume: _clamp(_audioValue(source, "volume",
        model ? model.inputVolume : 0))
    readonly property bool inputMuted: _audioBool(source, "muted",
        model && model.inputMuted)
    readonly property string outputName: _name(sink, "Output unavailable")
    readonly property string inputName: _name(source, "Microphone unavailable")
    readonly property int revision: model && model.revision !== undefined
        ? Number(model.revision)
        : 0
    readonly property string state: forceUnavailable
        ? "unavailable"
        : errorMessage !== ""
            ? "error"
            : outputActionBusy || outputRefreshBusy
                ? "busy"
                : available
                    ? "ready"
                    : "unavailable"
    readonly property var media: mediaService

    property PwObjectTracker pipewireTracker: PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    property Process listOutputsProcess: Process {
        command: ["pactl", "-f", "json", "list", "sinks"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root._parseOutputs(text)
        }
        onExited: function(exitCode) {
            root.outputRefreshBusy = false
            if (exitCode !== 0) {
                root.outputListParsed = false
                root.errorMessage = "Could not list output devices"
            } else if (!root.outputListParsed) {
                root.errorMessage = "Could not read output devices"
            }
        }
    }

    property Process selectOutputProcess: Process {
        onExited: function(exitCode) {
            root.outputActionBusy = false
            if (exitCode !== 0)
                root.errorMessage = "Could not switch output device"
            root.refreshOutputs()
        }
    }

    property MediaService mediaService: MediaService {
        context: root.context
    }

    Component.onCompleted: refreshOutputs()

    function refreshOutputs() {
        if (forceUnavailable || model !== null || listOutputsProcess.running)
            return forceUnavailable ? "unavailable" : "ok"
        outputListParsed = false
        outputRefreshBusy = true
        listOutputsProcess.running = true
        return "pending"
    }

    function setVolume(value) {
        if (!available)
            return "unavailable"
        var next = _clamp(value)
        if (model && typeof model.setVolume === "function")
            return model.setVolume(next)
        if (sink && sink.audio) {
            sink.audio.volume = next
            return "ok"
        }
        return "unavailable"
    }

    function toggleMuted() {
        if (!available)
            return "unavailable"
        if (model && typeof model.toggleMuted === "function")
            return model.toggleMuted()
        if (sink && sink.audio) {
            sink.audio.muted = !sink.audio.muted
            return "ok"
        }
        return "unavailable"
    }

    function setInputVolume(value) {
        if (!microphoneAvailable)
            return "unavailable"
        var next = _clamp(value)
        if (model && typeof model.setInputVolume === "function")
            return model.setInputVolume(next)
        if (source && source.audio) {
            source.audio.volume = next
            return "ok"
        }
        return "unavailable"
    }

    function toggleInputMuted() {
        if (!microphoneAvailable)
            return "unavailable"
        if (model && typeof model.toggleInputMuted === "function")
            return model.toggleInputMuted()
        if (source && source.audio) {
            source.audio.muted = !source.audio.muted
            return "ok"
        }
        return "unavailable"
    }

    function selectOutput(name) {
        if (!available || outputActionBusy)
            return forceUnavailable ? "unavailable" : "busy"
        var selectedName = String(name || "")
        if (!_hasOutput(selectedName))
            return "unavailable"
        errorMessage = ""
        if (model && typeof model.selectOutput === "function")
            return model.selectOutput(selectedName)
        outputActionBusy = true
        selectOutputProcess.command = ["pactl", "set-default-sink", selectedName]
        selectOutputProcess.running = true
        return "pending"
    }

    function _parseOutputs(text) {
        var parsed
        try {
            parsed = JSON.parse(String(text || "[]"))
        } catch (error) {
            outputListParsed = false
            systemOutputs = []
            errorMessage = "Could not read output devices"
            return
        }
        if (!Array.isArray(parsed)) {
            outputListParsed = false
            systemOutputs = []
            errorMessage = "Could not read output devices"
            return
        }

        var defaultName = String(Pipewire.defaultAudioSink
            ? Pipewire.defaultAudioSink.name || ""
            : "")
        var next = []
        for (var index = 0; index < parsed.length; index++) {
            var item = parsed[index]
            var name = String(item && item.name ? item.name : "")
            if (name === "")
                continue
            var description = String(item.description
                || item.properties && item.properties["device.description"]
                || name)
            next.push({
                name: name,
                description: description,
                active: name === defaultName,
                iconName: _outputIcon(item)
            })
        }
        next.sort(function(left, right) {
            if (left.active !== right.active)
                return left.active ? -1 : 1
            return left.description.localeCompare(right.description)
        })
        systemOutputs = next
        outputListParsed = true
        errorMessage = ""
    }

    function _outputIcon(item) {
        var detail = String(item && (item.description
            || item.active_port && item.active_port.name
            || item.name) || "").toLowerCase()
        return detail.indexOf("headphone") !== -1
                || detail.indexOf("headset") !== -1
                || detail.indexOf("bluetooth") !== -1
            ? "headphones"
            : "audio"
    }

    function _hasOutput(name) {
        for (var index = 0; index < outputs.length; index++)
            if (outputs[index] && String(outputs[index].name) === name)
                return true
        return false
    }

    function _activeOutputs() {
        var defaultName = String(sink ? sink.name || "" : "")
        var result = []
        for (var index = 0; index < systemOutputs.length; index++) {
            var output = systemOutputs[index]
            result.push({
                name: output.name,
                description: output.description,
                active: String(output.name) === defaultName,
                iconName: output.iconName
            })
        }
        return result
    }

    function _audioValue(node, key, fallback) {
        return node && node.audio && node.audio[key] !== undefined
            ? Number(node.audio[key])
            : Number(fallback || 0)
    }

    function _audioBool(node, key, fallback) {
        return node && node.audio && node.audio[key] !== undefined
            ? Boolean(node.audio[key])
            : Boolean(fallback)
    }

    function _name(node, fallback) {
        if (!node)
            return fallback
        return String(node.description || node.name || fallback)
    }

    function _clamp(value) {
        var number = Number(value)
        if (!isFinite(number))
            return 0
        return Math.max(0, Math.min(1, number))
    }
}
