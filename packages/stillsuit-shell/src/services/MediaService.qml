import QtQuick
import Quickshell.Services.Mpris

QtObject {
    id: root

    required property var context
    property var model: null
    property bool forceUnavailable: false
    property string selectedPlayerId: ""

    readonly property string apiVersion: "1"
    readonly property var players: model ? model.players || [] : Mpris.players.values
    readonly property var player: _selectedPlayer()
    readonly property var playerSummaries: _playerSummaries()
    readonly property bool available: !forceUnavailable
    readonly property bool failed: !forceUnavailable && Boolean(model && model.failed)
    readonly property string errorMessage: failed
        ? String(model.errorMessage || "Media controls are unavailable")
        : ""
    readonly property string state: forceUnavailable
        ? "unavailable"
        : failed
            ? "error"
            : player
                ? "ready"
                : "empty"
    readonly property string playerId: _id(player, -1)
    readonly property string playerName: player
        ? String(player.identity || player.desktopEntry || "Media player")
        : ""
    readonly property string title: _metadata("trackTitle", "Unknown track")
    readonly property string artist: _metadata("trackArtist",
        playerName !== "" ? playerName : "Unknown artist")
    readonly property string album: _metadata("trackAlbum", "")
    readonly property url artUrl: player && player.trackArtUrl
        ? player.trackArtUrl
        : ""
    readonly property bool isPlaying: Boolean(player && player.isPlaying)
    readonly property real position: _finiteNonNegative(player ? player.position : 0)
    readonly property real length: _finiteNonNegative(player ? player.length : 0)
    readonly property bool lengthSupported: Boolean(player
        && player.lengthSupported && length > 0)
    readonly property bool canSeek: Boolean(player && player.canSeek
        && lengthSupported)
    readonly property bool canGoPrevious: Boolean(player && player.canGoPrevious)
    readonly property bool canTogglePlaying: Boolean(player
        && player.canTogglePlaying)
    readonly property bool canGoNext: Boolean(player && player.canGoNext)
    readonly property bool shuffleSupported: Boolean(player
        && player.shuffleSupported)
    readonly property bool shuffle: Boolean(player && player.shuffle)
    readonly property bool repeatSupported: Boolean(player
        && player.loopSupported)
    readonly property string repeatMode: _repeatMode(player
        ? player.loopState
        : "none")

    property Timer positionTimer: Timer {
        interval: 500
        repeat: true
        running: root.model === null && root.isPlaying
        onTriggered: {
            if (root.player && typeof root.player.positionChanged === "function")
                root.player.positionChanged()
        }
    }

    function selectPlayer(id) {
        if (!available || failed)
            return "unavailable"
        var requested = String(id || "")
        for (var index = 0; index < players.length; index++) {
            if (_id(players[index], index) === requested) {
                selectedPlayerId = requested
                return "ok"
            }
        }
        return "unavailable"
    }

    function previous() {
        if (!canGoPrevious)
            return "unavailable"
        if (model && typeof model.previous === "function")
            return model.previous(player)
        player.previous()
        return "ok"
    }

    function togglePlaying() {
        if (!canTogglePlaying)
            return "unavailable"
        if (model && typeof model.togglePlaying === "function")
            return model.togglePlaying(player)
        player.togglePlaying()
        return "ok"
    }

    function next() {
        if (!canGoNext)
            return "unavailable"
        if (model && typeof model.next === "function")
            return model.next(player)
        player.next()
        return "ok"
    }

    function seekTo(seconds) {
        if (!canSeek)
            return "unavailable"
        var target = Math.max(0, Math.min(length, Number(seconds)))
        if (!isFinite(target))
            return "unavailable"
        if (model && typeof model.seekTo === "function")
            return model.seekTo(player, target)
        player.seek(target - position)
        return "ok"
    }

    function toggleShuffle() {
        if (!shuffleSupported)
            return "unavailable"
        var nextShuffle = !shuffle
        if (model && typeof model.setShuffle === "function")
            return model.setShuffle(player, nextShuffle)
        player.shuffle = nextShuffle
        return "ok"
    }

    function cycleRepeat() {
        if (!repeatSupported)
            return "unavailable"
        var nextMode = repeatMode === "none"
            ? "playlist"
            : repeatMode === "playlist"
                ? "track"
                : "none"
        if (model && typeof model.setRepeatMode === "function")
            return model.setRepeatMode(player, nextMode)
        player.loopState = _nativeRepeatMode(nextMode)
        return "ok"
    }

    function _selectedPlayer() {
        if (!available || failed || players.length === 0)
            return null
        if (selectedPlayerId !== "") {
            for (var selectedIndex = 0; selectedIndex < players.length;
                    selectedIndex++)
                if (_id(players[selectedIndex], selectedIndex) === selectedPlayerId)
                    return players[selectedIndex]
        }
        for (var playingIndex = 0; playingIndex < players.length; playingIndex++)
            if (players[playingIndex] && players[playingIndex].isPlaying)
                return players[playingIndex]
        return players[0]
    }

    function _playerSummaries() {
        var summaries = []
        for (var index = 0; index < players.length; index++) {
            var candidate = players[index]
            if (!candidate)
                continue
            summaries.push({
                id: _id(candidate, index),
                name: String(candidate.identity || candidate.desktopEntry
                    || "Media player"),
                title: String(candidate.trackTitle || "Unknown track"),
                playing: Boolean(candidate.isPlaying),
                selected: candidate === player
            })
        }
        return summaries
    }

    function _id(candidate, index) {
        if (!candidate)
            return ""
        return String(candidate.dbusName || candidate.uniqueId
            || candidate.identity || "player-" + index)
    }

    function _metadata(key, fallback) {
        if (!player)
            return ""
        var value = String(player[key] || "").trim()
        return value !== "" ? value : fallback
    }

    function _finiteNonNegative(value) {
        var number = Number(value || 0)
        return isFinite(number) ? Math.max(0, number) : 0
    }

    function _repeatMode(value) {
        if (value === MprisLoopState.Track || String(value).toLowerCase() === "track")
            return "track"
        if (value === MprisLoopState.Playlist
                || String(value).toLowerCase() === "playlist")
            return "playlist"
        return "none"
    }

    function _nativeRepeatMode(mode) {
        if (mode === "track")
            return MprisLoopState.Track
        if (mode === "playlist")
            return MprisLoopState.Playlist
        return MprisLoopState.None
    }
}
