pragma ComponentBehavior: Bound

import QtQuick

// Read-only HostContext v1 compositor snapshot. NiriService is its only writer.
// Rows are never mutated after assignment: a changed row is replaced by a new
// object and an unchanged row keeps its identity, so keyed views such as
// ScriptModel only touch the rows that changed.
QtObject {
    id: root

    readonly property string apiVersion: "1"
    readonly property string name: "niri"
    property int revision: 0
    property var outputs: []
    property string focusedOutputId: ""
    property var workspaces: []
    property var windows: []
    // The id of the window niri most recently flagged focused. It survives
    // focus moving to a layer surface (a Stillsuit menu or panel) or to no
    // window, and becomes null once that window closes.
    readonly property var lastFocusedWindowId: root._lastFocusedWindowId
    property var _lastFocusedWindowId: null

    function replace(nextOutputs, nextFocusedOutputId, nextWorkspaces, nextWindows) {
        return update({
            outputs: nextOutputs,
            focusedOutputId: nextFocusedOutputId,
            workspaces: nextWorkspaces,
            windows: nextWindows
        })
    }

    // Applies only the collections present in `changes`; absent keys keep
    // their current value. Passing the current array back is a no-op.
    function update(changes) {
        var nextOutputs = "outputs" in changes ? _mergeRows(outputs, changes.outputs) : outputs
        var nextWorkspaces = "workspaces" in changes ? _mergeRows(workspaces, changes.workspaces) : workspaces
        var nextWindows = "windows" in changes ? _mergeRows(windows, changes.windows) : windows
        var nextFocused = "focusedOutputId" in changes ? String(changes.focusedOutputId || "") : focusedOutputId
        var changed = false
        if (nextOutputs !== outputs) { outputs = nextOutputs; changed = true }
        if (nextFocused !== focusedOutputId) { focusedOutputId = nextFocused; changed = true }
        if (nextWorkspaces !== workspaces) { workspaces = nextWorkspaces; changed = true }
        if (nextWindows !== windows) {
            windows = nextWindows
            _lastFocusedWindowId = _lastFocused(nextWindows, _lastFocusedWindowId)
            changed = true
        }
        if (changed) revision += 1
        return changed
    }

    // Returns `previous` when nothing differs. Otherwise returns a new array
    // that reuses every previous row whose content is unchanged (matched by
    // position, then by id) and stores a detached copy of each changed row.
    function _mergeRows(previous, next) {
        if (next === previous) return previous
        if (!Array.isArray(next)) return previous.length === 0 ? previous : []
        try {
            var previousById = null
            var merged = new Array(next.length)
            var changed = next.length !== previous.length
            for (var index = 0; index < next.length; index++) {
                var row = next[index]
                var positional = index < previous.length ? previous[index] : undefined
                if (row === positional) {
                    merged[index] = row
                    continue
                }
                var text = JSON.stringify(row)
                var candidate = positional
                if (!_sameId(candidate, row)) {
                    if (previousById === null) previousById = _indexById(previous)
                    candidate = row && row.id !== undefined ? previousById[String(row.id)] : undefined
                }
                if (candidate !== undefined && JSON.stringify(candidate) === text) {
                    merged[index] = candidate
                    if (candidate !== positional) changed = true
                    continue
                }
                merged[index] = text === undefined ? null : JSON.parse(text)
                changed = true
            }
            return changed ? merged : previous
        } catch (error) {
            console.warn("stillsuit compositor: rejected non-plain snapshot rows: " + error)
            return previous.length === 0 ? previous : []
        }
    }

    function _lastFocused(rows, previous) {
        var previousOpen = false
        for (var index = 0; index < rows.length; index++) {
            var row = rows[index]
            if (!row || row.id === undefined) continue
            if (row.is_focused === true) return row.id
            if (row.id === previous) previousOpen = true
        }
        return previousOpen ? previous : null
    }

    function _sameId(left, right) {
        return !!left && !!right && left.id !== undefined && left.id === right.id
    }

    function _indexById(rows) {
        var byId = {}
        for (var index = 0; index < rows.length; index++) {
            var row = rows[index]
            if (row && row.id !== undefined) byId[String(row.id)] = row
        }
        return byId
    }
}
