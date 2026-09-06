import QtQuick
import Quickshell.Io

QtObject {
    id: root

    required property var context
    property var model: null
    property bool forceUnavailable: false
    readonly property string apiVersion: "1"
    property var profiles: []
    property string activeProfile: ""
    property string pendingProfile: ""
    property bool busy: false
    property string errorMessage: ""
    property bool refreshQueued: false
    property int internalRevision: 0
    readonly property string displayProfile: pendingProfile !== ""
        ? pendingProfile
        : activeProfile
    readonly property bool available: !forceUnavailable
        && (model !== null || activeProfile !== "")
    readonly property int revision: model && model.revision !== undefined
        ? Number(model.revision)
        : internalRevision
    readonly property var helperArgv: ["powerprofilesctl", "get"]

    property Process getProfile: Process {
        id: getProfile

        command: root.helperArgv
        stdout: StdioCollector {
            id: profileOutput
            waitForEnd: true
        }
        onExited: function(exitCode) {
            root._finishRefresh(exitCode, profileOutput.text)
        }
    }

    property Process setProfileProcess: Process {
        onExited: function(exitCode) {
            root._finishProfileSet(exitCode)
        }
    }

    property Timer reconcileTimer: Timer {
        interval: 15000
        running: root.model === null
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    property Connections modelConnections: Connections {
        target: root.model
        ignoreUnknownSignals: true

        function onRevisionChanged() {
            root._syncModel()
        }

        function onActiveProfileChanged() {
            root._syncModel()
        }

        function onProfilesChanged() {
            root._syncModel()
        }
    }

    Component.onCompleted: {
        if (model)
            _syncModel()
    }

    function refresh() {
        if (model) {
            _syncModel()
            return
        }
        if (getProfile.running) {
            refreshQueued = true
            return
        }
        getProfile.running = true
    }

    function setProfile(profile) {
        if (forceUnavailable || !available)
            return "unavailable"
        var next = String(profile || "")
        if (profiles.indexOf(next) === -1)
            return "unavailable"
        if (busy)
            return "busy"
        if (next === activeProfile)
            return "ok"

        pendingProfile = next
        busy = true
        errorMessage = ""

        if (model && typeof model.setProfile === "function") {
            var result = String(model.setProfile(next) || "error")
            if (result === "ok") {
                _syncModel()
            } else if (result !== "pending") {
                _rollback("Could not change the power profile.")
                return "error"
            }
            return result
        }

        setProfileProcess.command = ["powerprofilesctl", "set", next]
        setProfileProcess.running = true
        return "ok"
    }

    function _syncModel() {
        if (!model)
            return
        var nextProfiles = _normalizeProfiles(model.profiles)
        if (nextProfiles.length > 0)
            profiles = nextProfiles
        var authoritative = _normalizeProfile(model.activeProfile)
        if (authoritative !== "")
            activeProfile = authoritative
        if (pendingProfile !== "" && activeProfile === pendingProfile) {
            pendingProfile = ""
            busy = false
            errorMessage = ""
        }
    }

    function _finishProfileSet(exitCode) {
        if (Number(exitCode) !== 0) {
            _rollback("Could not change the power profile.")
            refresh()
            return
        }
        refresh()
    }

    function _finishRefresh(exitCode, text) {
        var runQueuedRefresh = refreshQueued
        refreshQueued = false
        if (Number(exitCode) !== 0) {
            if (busy && !setProfileProcess.running && !runQueuedRefresh)
                _rollback("Could not confirm the power profile.")
            if (runQueuedRefresh)
                Qt.callLater(refresh)
            return
        }
        var authoritative = _normalizeProfile(text)
        if (authoritative === "") {
            if (busy && !setProfileProcess.running && !runQueuedRefresh)
                _rollback("Could not confirm the power profile.")
            if (runQueuedRefresh)
                Qt.callLater(refresh)
            return
        }
        activeProfile = authoritative
        profiles = ["power-saver", "balanced", "performance"]
        internalRevision++
        if (pendingProfile !== "" && !setProfileProcess.running
                && !runQueuedRefresh) {
            if (pendingProfile !== authoritative)
                errorMessage = "The daemon kept " + _profileLabel(authoritative) + "."
            else
                errorMessage = ""
            pendingProfile = ""
            busy = false
        }
        if (pendingProfile === "")
            busy = false
        if (runQueuedRefresh)
            Qt.callLater(refresh)
    }

    function _rollback(message) {
        pendingProfile = ""
        busy = false
        errorMessage = String(message || "Could not change the power profile.")
    }

    function _normalizeProfiles(values) {
        if (!Array.isArray(values))
            return []
        var result = []
        for (var index = 0; index < values.length; index++) {
            var profile = _normalizeProfile(values[index])
            if (profile !== "" && result.indexOf(profile) === -1)
                result.push(profile)
        }
        return result
    }

    function _normalizeProfile(value) {
        var profile = String(value || "").trim()
        return profile === "power-saver"
                || profile === "balanced"
                || profile === "performance"
            ? profile
            : ""
    }

    function _profileLabel(profile) {
        if (profile === "power-saver")
            return "Power saver"
        if (profile === "performance")
            return "Performance"
        return "Balanced"
    }
}
