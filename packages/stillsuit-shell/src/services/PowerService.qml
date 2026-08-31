import QtQuick
import Quickshell.Io

QtObject {
    id: root

    required property var context
    property var model: null
    readonly property string apiVersion: "1"
    property var profiles: []
    property string activeProfile: ""
    readonly property bool available: model !== null || profiles.length > 0
    readonly property int revision: model && model.revision !== undefined ? Number(model.revision) : 0
    readonly property var helperArgv: ["powerprofilesctl", "get"]

    property Process getProfile: Process {
        id: getProfile
        command: root.helperArgv
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: root._setProfile(text) }
    }
    Component.onCompleted: if (!root.model) getProfile.running = true
    function _setProfile(text) {
        var value = String(text || "").trim()
        if (value !== "") { activeProfile = value; profiles = ["power-saver", "balanced", "performance"] }
    }
    function setProfile(profile) {
        var next = String(profile)
        if (model && typeof model.setProfile === "function") return model.setProfile(next)
        if (profiles.indexOf(next) === -1) return "unavailable"
        setProfileProcess.command = ["powerprofilesctl", "set", next]
        setProfileProcess.running = true
        activeProfile = next
        return "ok"
    }
    property Process setProfileProcess: Process { }
}
