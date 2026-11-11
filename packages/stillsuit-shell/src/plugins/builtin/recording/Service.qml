import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Live microphone level for the recording indicator. The recorder captures
// PipeWire's default input, so this meters that same node, and only while a
// recording that includes the microphone is running and unpaused.
Scope {
    id: root

    required property var context

    readonly property string apiVersion: "1"
    readonly property var workflows: context.services ? context.services.get("stillsuit.workflows") :
                                                        null
    readonly property var recording: workflows ? workflows.recording : null
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool microphoneCaptured: !!recording && recording.active === true && !
                                               !recording.snapshot && recording.snapshot.microphone
                                               === true
    readonly property bool microphoneMuted: !!source && !!source.audio && source.audio.muted
                                            === true

    readonly property bool microphoneLive: microphoneCaptured && !microphoneMuted && !!source
                                           && recording.paused !== true
    readonly property real level: microphoneLive ? smoothedLevel : 0

    readonly property var settings: context.settings ? context.settings.values : ({})
    readonly property real floorDb: _settingNumber("microphoneFloorDb", -32)
    readonly property real ceilingDb: Math.max(floorDb + 1, _settingNumber("microphoneCeilingDb",
                                                                           -6))

    property real smoothedLevel: 0

    function _settingNumber(key, fallback) {
        var value = settings ? Number(settings[key]) : NaN
        return isFinite(value) ? value : fallback
    }

    // PwNodePeakMonitor reports the cube root of the sample peak.
    function _levelFromPeak(peak) {
        var visualPeak = Number(peak)
        if (!isFinite(visualPeak) || visualPeak <= 0)
            return 0
        var amplitude = visualPeak * visualPeak * visualPeak
        var db = 20 * Math.log(amplitude) / Math.LN10
        return Math.max(0, Math.min(1, (db - floorDb) / (ceilingDb - floorDb)))
    }

    function _push(peak) {
        var target = _levelFromPeak(peak)
        var rising = target > smoothedLevel
        smoothedLevel += (target - smoothedLevel) * (rising ? 0.6 : 0.15)
    }

    onMicrophoneLiveChanged: if (!microphoneLive)
                                 smoothedLevel = 0

    PwObjectTracker {
        objects: root.source ? [root.source] : []
    }

    PwNodePeakMonitor {
        node: root.source
        enabled: root.microphoneLive
        onPeakChanged: root._push(peak)
    }
}
