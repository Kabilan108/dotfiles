pragma ComponentBehavior: Bound

import QtQuick

// Read-only HostContext v1 compositor snapshot. NiriService is its only writer.
QtObject {
    id: root

    readonly property string apiVersion: "1"
    readonly property string name: "niri"
    property int revision: 0
    property var outputs: []
    property string focusedOutputId: ""
    property var workspaces: []
    property var windows: []

    function replace(nextOutputs, nextFocusedOutputId, nextWorkspaces, nextWindows) {
        var candidate = {
            outputs: _plainArray(nextOutputs),
            focusedOutputId: String(nextFocusedOutputId || ""),
            workspaces: _plainArray(nextWorkspaces),
            windows: _plainArray(nextWindows)
        }
        var previous = {
            outputs: outputs,
            focusedOutputId: focusedOutputId,
            workspaces: workspaces,
            windows: windows
        }
        if (JSON.stringify(candidate) === JSON.stringify(previous)) return false
        outputs = candidate.outputs
        focusedOutputId = candidate.focusedOutputId
        workspaces = candidate.workspaces
        windows = candidate.windows
        revision += 1
        return true
    }

    function _plainArray(value) {
        if (!Array.isArray(value)) return []
        try {
            var cloned = JSON.parse(JSON.stringify(value))
            return Array.isArray(cloned) ? cloned : []
        } catch (error) {
            return []
        }
    }
}
