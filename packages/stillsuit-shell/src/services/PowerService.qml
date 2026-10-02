import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower

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
    property bool daemonAvailable: false
    property int internalRevision: 0
    readonly property string displayProfile: pendingProfile !== ""
        ? pendingProfile
        : activeProfile
    readonly property bool available: !forceUnavailable
        && (model !== null || (daemonAvailable && activeProfile !== ""))
    readonly property int revision: model && model.revision !== undefined
        ? Number(model.revision)
        : internalRevision
    // PowerProfiles reports Balanced even when power-profiles-daemon is absent,
    // so a one-shot read decides availability; live changes then come from the
    // singleton's PropertiesChanged tracking.
    readonly property var probeArgv: ["powerprofilesctl", "list"]

    property Process daemonProbe: Process {
        id: daemonProbe

        command: root.probeArgv
        stdout: StdioCollector {
            id: probeOutput
            waitForEnd: true
        }
        onExited: function(exitCode) {
            root._finishProbe(exitCode, probeOutput.text)
        }
    }

    // Quickshell writes the profile optimistically and only logs a rejected
    // D-Bus Set, so a later read confirms what the daemon kept.
    property Timer confirmTimer: Timer {
        interval: 750
        repeat: false
        onTriggered: root.refresh()
    }

    property Connections daemonConnections: Connections {
        target: root.model === null && root.daemonAvailable ? PowerProfiles : null
        ignoreUnknownSignals: true

        function onProfileChanged() {
            var profile = root._profileName(PowerProfiles.profile)
            if (profile !== "" && profile !== root.activeProfile) {
                root.activeProfile = profile
                root.internalRevision++
            }
        }

        function onHasPerformanceProfileChanged() {
            root.profiles = root._withPerformance(root.profiles,
                PowerProfiles.hasPerformanceProfile)
            root.internalRevision++
        }
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

    Component.onCompleted: refresh()

    function refresh() {
        if (model) {
            _syncModel()
            return
        }
        if (daemonProbe.running) {
            refreshQueued = true
            return
        }
        daemonProbe.running = true
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

        var requested = _profileEnum(next)
        PowerProfiles.profile = requested
        if (PowerProfiles.profile !== requested) {
            _rollback("Could not change the power profile.")
            return "error"
        }
        confirmTimer.restart()
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

    function _finishProbe(exitCode, text) {
        if (refreshQueued) {
            refreshQueued = false
            Qt.callLater(refresh)
            return
        }
        if (model)
            return
        var state = Number(exitCode) === 0 ? _parseProbe(text) : null
        if (!state) {
            daemonAvailable = false
            activeProfile = ""
            profiles = []
            internalRevision++
            if (busy)
                _rollback("Could not confirm the power profile.")
            return
        }
        activeProfile = state.activeProfile
        profiles = state.profiles
        daemonAvailable = true
        internalRevision++
        if (pendingProfile !== "") {
            if (pendingProfile !== state.activeProfile)
                errorMessage = "The daemon kept " + _profileLabel(state.activeProfile) + "."
            else
                errorMessage = ""
            pendingProfile = ""
        }
        busy = false
    }

    function _parseProbe(raw) {
        var lines = String(raw || "").split("\n")
        var active = ""
        var listed = []
        for (var index = 0; index < lines.length; index++) {
            var match = /^([* ]) ([a-z-]+):$/.exec(lines[index])
            if (!match)
                continue
            var profile = _normalizeProfile(match[2])
            if (profile === "")
                continue
            listed.push(profile)
            if (match[1] === "*")
                active = profile
        }
        if (active === "")
            return null
        return {
            activeProfile: active,
            profiles: _canonicalOrder(listed)
        }
    }

    function _withPerformance(values, present) {
        var next = values.filter(function(profile) {
            return profile !== "performance"
        })
        if (present)
            next.push("performance")
        return _canonicalOrder(next)
    }

    function _canonicalOrder(values) {
        return ["power-saver", "balanced", "performance"].filter(function(profile) {
            return values.indexOf(profile) !== -1
        })
    }

    function _profileName(value) {
        if (value === PowerProfile.PowerSaver)
            return "power-saver"
        if (value === PowerProfile.Balanced)
            return "balanced"
        if (value === PowerProfile.Performance)
            return "performance"
        return ""
    }

    function _profileEnum(profile) {
        if (profile === "power-saver")
            return PowerProfile.PowerSaver
        if (profile === "performance")
            return PowerProfile.Performance
        return PowerProfile.Balanced
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
