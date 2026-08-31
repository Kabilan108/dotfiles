import QtQuick
import Quickshell.Services.Pipewire

QtObject {
    id: root

    required property var context
    // Tests inject a plain model. Production reads PipeWire without making a
    // process or timer per output.
    property var model: null
    readonly property string apiVersion: "1"
    readonly property bool available: model !== null || Pipewire.defaultAudioSink !== null
    readonly property var sink: model ? model.sink || null : Pipewire.defaultAudioSink
    readonly property var source: model ? model.source || null : Pipewire.defaultAudioSource
    readonly property var outputs: model ? model.outputs || [] : []
    readonly property var inputs: model ? model.inputs || [] : []
    readonly property real volume: sink && sink.audio ? Number(sink.audio.volume || 0) : Number(model ? model.volume || 0 : 0)
    readonly property bool muted: sink && sink.audio ? Boolean(sink.audio.muted) : Boolean(model && model.muted)
    readonly property string outputName: _name(sink, "Output unavailable")
    readonly property string inputName: _name(source, "Input unavailable")
    readonly property int revision: model && model.revision !== undefined ? Number(model.revision) : 0

    function _name(node, fallback) {
        if (!node)
            return fallback
        return String(node.description || node.name || fallback)
    }

    function setVolume(value) {
        var next = Math.max(0, Math.min(1.5, Number(value)))
        if (model && typeof model.setVolume === "function")
            return model.setVolume(next)
        if (sink && sink.audio)
            sink.audio.volume = next
        return available ? "ok" : "unavailable"
    }

    function toggleMuted() {
        if (model && typeof model.toggleMuted === "function")
            return model.toggleMuted()
        if (sink && sink.audio)
            sink.audio.muted = !sink.audio.muted
        return available ? "ok" : "unavailable"
    }

    function selectOutput(name) {
        if (model && typeof model.selectOutput === "function")
            return model.selectOutput(String(name))
        return "unavailable"
    }

    function selectInput(name) {
        if (model && typeof model.selectInput === "function")
            return model.selectInput(String(name))
        return "unavailable"
    }
}
