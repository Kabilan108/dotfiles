import QtQuick
import Quickshell
import "services" as Services

ShellRoot {
    id: root

    property int checks: 0
    property var fakeContext: QtObject {}
    property real lastOutputVolume: -1
    property real lastInputVolume: -1
    property string selectedOutput: ""
    property int outputMuteCalls: 0
    property int inputMuteCalls: 0
    property int previousCalls: 0
    property int playPauseCalls: 0
    property int nextCalls: 0
    property real seekTarget: -1
    property bool requestedShuffle: false
    property string requestedRepeat: ""
    property var viewComponents: []

    QtObject {
        id: fakeAudioModel

        property int revision: 4
        property real volume: 1.4
        property bool muted: false
        property real inputVolume: 0.3
        property bool inputMuted: true
        property string selectStatus: "ok"
        property var sink: ({ description: "Fixture speakers" })
        property var source: ({ description: "Fixture microphone" })
        property var outputs: [
            { name: "sink.speakers", description: "Speakers", active: true,
                iconName: "audio" },
            { name: "sink.headset", description: "Headset", active: false,
                iconName: "headphones" }
        ]

        function setVolume(value) {
            root.lastOutputVolume = value
            volume = value
            return "ok"
        }
        function toggleMuted() {
            root.outputMuteCalls++
            muted = !muted
            return "ok"
        }
        function setInputVolume(value) {
            root.lastInputVolume = value
            inputVolume = value
            return "ok"
        }
        function toggleInputMuted() {
            root.inputMuteCalls++
            inputMuted = !inputMuted
            return "ok"
        }
        function selectOutput(name) {
            root.selectedOutput = name
            return selectStatus
        }
    }

    QtObject {
        id: pausedPlayer

        property string dbusName: "paused"
        property string identity: "Paused Player"
        property string trackTitle: "Paused track"
        property string trackArtist: "Artist A"
        property string trackAlbum: "Album A"
        property string trackArtUrl: ""
        property bool isPlaying: false
        property real position: 12
        property real length: 90
        property bool lengthSupported: true
        property bool canSeek: false
        property bool canGoPrevious: false
        property bool canTogglePlaying: true
        property bool canGoNext: false
        property bool shuffleSupported: false
        property bool shuffle: false
        property bool loopSupported: false
        property string loopState: "none"
    }

    QtObject {
        id: playingPlayer

        property string dbusName: "playing"
        property string identity: "Playing Player"
        property string trackTitle: "Playing track"
        property string trackArtist: "Artist B"
        property string trackAlbum: "Album B"
        property string trackArtUrl: "file:///fixture-cover.png"
        property bool isPlaying: true
        property real position: 45
        property real length: 240
        property bool lengthSupported: true
        property bool canSeek: true
        property bool canGoPrevious: true
        property bool canTogglePlaying: true
        property bool canGoNext: true
        property bool shuffleSupported: true
        property bool shuffle: false
        property bool loopSupported: true
        property string loopState: "none"
    }

    QtObject {
        id: fallbackPlayer

        property string dbusName: "fallback"
        property string identity: "Fallback Player"
        property string trackTitle: ""
        property string trackArtist: ""
        property string trackAlbum: ""
        property string trackArtUrl: ""
        property bool isPlaying: false
        property real position: 0
        property real length: 0
        property bool lengthSupported: false
        property bool canSeek: false
        property bool canGoPrevious: false
        property bool canTogglePlaying: false
        property bool canGoNext: false
        property bool shuffleSupported: false
        property bool shuffle: false
        property bool loopSupported: false
        property string loopState: "none"
    }

    QtObject {
        id: fakeMediaModel

        property var players: [pausedPlayer, playingPlayer]
        property bool failed: false
        property string errorMessage: ""

        function previous(player) {
            root.previousCalls++
            return "ok"
        }
        function togglePlaying(player) {
            root.playPauseCalls++
            return "ok"
        }
        function next(player) {
            root.nextCalls++
            return "ok"
        }
        function seekTo(player, target) {
            root.seekTarget = target
            return "ok"
        }
        function setShuffle(player, enabled) {
            root.requestedShuffle = enabled
            player.shuffle = enabled
            return "ok"
        }
        function setRepeatMode(player, mode) {
            root.requestedRepeat = mode
            player.loopState = mode
            return "ok"
        }
    }

    QtObject {
        id: fallbackMediaModel
        property var players: [fallbackPlayer]
        property bool failed: false
        property string errorMessage: ""
    }

    QtObject {
        id: failedMediaModel
        property var players: []
        property bool failed: true
        property string errorMessage: "Fixture MPRIS failure"
    }

    Services.AudioService {
        id: audio
        context: root.fakeContext
        model: fakeAudioModel
    }

    Services.AudioService {
        id: unavailableAudio
        context: root.fakeContext
        model: fakeAudioModel
        forceUnavailable: true
    }

    Services.MediaService {
        id: media
        context: root.fakeContext
        model: fakeMediaModel
    }

    Component.onCompleted: {
        viewComponents = [
            Qt.createComponent("plugins/builtin/audio/Widget.qml")
        ]
    }

    Services.MediaService {
        id: fallbackMedia
        context: root.fakeContext
        model: fallbackMediaModel
    }

    Services.MediaService {
        id: failedMedia
        context: root.fakeContext
        model: failedMediaModel
    }

    Services.MediaService {
        id: unavailableMedia
        context: root.fakeContext
        model: fakeMediaModel
        forceUnavailable: true
    }

    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: root.runContracts()
    }

    function runContracts() {
        _assert(viewComponents[0].status === Component.Ready,
            "bar widget compiles: " + viewComponents[0].errorString())
        _assert(audio.apiVersion === "1", "audio API version")
        _assert(audio.volume === 1, "read volume clamp")
        _assert(audio.inputVolume === 0.3, "microphone level")
        _assert(audio.outputName === "Fixture speakers", "output metadata")
        _assert(audio.inputName === "Fixture microphone", "input metadata")
        _assert(audio.outputs.length === 2, "output device list")
        _assert(audio.setVolume(2.5) === "ok" && lastOutputVolume === 1,
            "write volume upper clamp")
        _assert(audio.setVolume(-4) === "ok" && lastOutputVolume === 0,
            "write volume lower clamp")
        _assert(audio.setInputVolume(9) === "ok" && lastInputVolume === 1,
            "microphone upper clamp")
        _assert(audio.toggleMuted() === "ok" && outputMuteCalls === 1,
            "output mute")
        _assert(audio.toggleInputMuted() === "ok" && inputMuteCalls === 1,
            "microphone mute")
        _assert(audio.selectOutput("sink.headset") === "ok"
            && selectedOutput === "sink.headset", "output selection")
        fakeAudioModel.selectStatus = "error"
        _assert(audio.selectOutput("sink.speakers") === "error",
            "output selection failure")
        fakeAudioModel.selectStatus = "ok"
        _assert(audio.selectOutput("not-an-output") === "unavailable"
            && selectedOutput === "sink.speakers", "unknown output containment")
        audio._parseOutputs('[{"name":"z","description":"Bluetooth Headset"},'
            + '{"name":"a","description":"Speakers"}]')
        _assert(audio.systemOutputs.length === 2
            && audio.systemOutputs[0].name === "z", "output list parsing")
        _assert(audio.systemOutputs[0].iconName === "headphones",
            "output icon classification")
        audio._parseOutputs("not-json")
        _assert(audio.errorMessage === "Could not read output devices"
            && audio.systemOutputs.length === 0, "output list parse failure")
        _assert(unavailableAudio.setVolume(0.5) === "unavailable"
            && unavailableAudio.toggleInputMuted() === "unavailable",
            "unavailable audio containment")

        _assert(media.playerId === "playing", "active player first")
        _assert(media.title === "Playing track" && media.artist === "Artist B"
            && media.album === "Album B", "media metadata")
        _assert(media.playerSummaries.length === 2
            && media.playerSummaries[1].selected, "multiple player summaries")
        _assert(media.previous() === "ok" && previousCalls === 1,
            "previous transport")
        _assert(media.togglePlaying() === "ok" && playPauseCalls === 1,
            "play pause transport")
        _assert(media.next() === "ok" && nextCalls === 1,
            "next transport")
        _assert(media.seekTo(999) === "ok" && seekTarget === 240,
            "absolute seek clamp")
        _assert(media.toggleShuffle() === "ok" && requestedShuffle,
            "shuffle control")
        _assert(media.cycleRepeat() === "ok" && requestedRepeat === "playlist",
            "repeat playlist")
        _assert(media.cycleRepeat() === "ok" && requestedRepeat === "track",
            "repeat track")
        _assert(media.cycleRepeat() === "ok" && requestedRepeat === "none",
            "repeat none")
        _assert(media.selectPlayer("paused") === "ok"
            && media.playerId === "paused", "explicit player selection")
        _assert(media.previous() === "unavailable" && previousCalls === 1,
            "previous capability gate")
        _assert(media.seekTo(30) === "unavailable" && seekTarget === 240,
            "seek capability gate")
        _assert(media.toggleShuffle() === "unavailable",
            "shuffle capability gate")
        _assert(media.cycleRepeat() === "unavailable",
            "repeat capability gate")
        _assert(fallbackMedia.title === "Unknown track"
            && fallbackMedia.artist === "Fallback Player"
            && fallbackMedia.artUrl.toString() === "", "metadata fallback")
        _assert(failedMedia.state === "error"
            && failedMedia.errorMessage === "Fixture MPRIS failure",
            "media failure state")
        _assert(unavailableMedia.state === "unavailable"
            && unavailableMedia.next() === "unavailable",
            "media unavailable state")

        console.log("AUDIO_MEDIA_FIXTURE_OK checks=" + checks)
        Qt.quit()
    }

    function _assert(condition, name) {
        if (!condition) {
            console.error("AUDIO_MEDIA_FIXTURE_FAIL " + name)
            Qt.quit()
            throw new Error(name)
        }
        checks++
    }
}
