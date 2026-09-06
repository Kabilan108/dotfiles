// A HostContext v1 compositor snapshot driven by the fixture instead of Niri.
// Outputs come from the real Quickshell screens so per-output plugins and the
// panel hosts see the same output identities the windows are on.
import QtQuick
import Quickshell

QtObject {
    id: root

    readonly property string apiVersion: "1"
    readonly property string name: "workbench"
    property int revision: 0
    property var outputs: []
    property string focusedOutputId: ""
    property var workspaces: []
    property var windows: []

    function apply(snapshot, screens) {
        var nextOutputs = []
        for (var index = 0; index < screens.length; index++)
            nextOutputs.push({ id: String(screens[index].name), name: String(screens[index].name) })
        var primary = nextOutputs.length > 0 ? nextOutputs[0].id : ""
        var requested = String(snapshot.focusedOutputId || "")
        var focused = nextOutputs.some(function(output) { return output.id === requested }) ? requested : primary
        outputs = nextOutputs
        focusedOutputId = focused
        workspaces = _retarget(snapshot.workspaces || [], primary)
        windows = JSON.parse(JSON.stringify(snapshot.windows || []))
        revision += 1
    }

    // Fixtures name their output "WB-1"; map it onto whatever the first real
    // screen is called so workspace views find their rows.
    function _retarget(rows, primary) {
        var result = JSON.parse(JSON.stringify(rows))
        for (var index = 0; index < result.length; index++) {
            if (result[index].output === "WB-1") result[index].output = primary
            if (result[index].output_id === "WB-1") result[index].output_id = primary
        }
        return result
    }
}
