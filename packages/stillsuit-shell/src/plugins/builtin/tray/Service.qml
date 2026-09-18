import QtQuick
import Quickshell.Services.SystemTray

// Importing SystemTray registers this process as the session's
// StatusNotifierWatcher/Host, which is what lets Electron and Qt apps offer a
// tray icon at all: without a watcher on the bus they never create one.
QtObject {
    id: root

    required property var context
    readonly property string apiVersion: "1"
    // Workbench fixture input; null means the live StatusNotifier bus.
    property var model: null

    readonly property var rawItems: model ? (model.items || []) : (SystemTray.items ? SystemTray.items.values : [])
    readonly property var items: visibleItems(rawItems)
    readonly property int count: items.length
    readonly property bool attention: items.some(function(item) { return statusOf(item) === "attention" })

    function statusOf(item) {
        if (!item) return "passive"
        if (typeof item.status === "string") return item.status
        if (item.status === Status.Passive) return "passive"
        if (item.status === Status.NeedsAttention) return "attention"
        return "active"
    }

    function visibleItems(rows) {
        var result = []
        for (var index = 0; index < rows.length; index++) {
            var item = rows[index]
            if (!item || statusOf(item) === "passive") continue
            result.push(item)
        }
        result.sort(function(left, right) {
            return String(left.id || "").toLowerCase().localeCompare(String(right.id || "").toLowerCase())
        })
        return result
    }

    function itemById(id) {
        var key = String(id || "")
        for (var index = 0; index < items.length; index++) {
            if (String(items[index].id || "") === key) return items[index]
        }
        return null
    }

    function tooltipFor(item) {
        if (!item) return ""
        return String(item.tooltipTitle || item.title || item.id || "")
    }

    // SNI ids are app-chosen ("Slack_status_icon_1", "discord_status_icon_1",
    // "blueman"); the compositor knows windows by app_id ("slack", "discord").
    // Match on the leading identifier token so a tray item can be tied to its
    // open windows without a per-app table.
    function appKey(item) {
        var source = String((item && (item.id || item.title)) || "").toLowerCase()
        var match = source.match(/^[a-z0-9.+-]+/)
        var key = match ? match[0] : source
        return key.replace(/[._-]?(status[._-]?icon|tray|indicator|applet|sni)$/, "")
    }

    // A window matches when its app_id equals the key outright, or when the
    // last dotted segment of a reverse-DNS app_id does ("org.foo.slack").
    // No prefix matching: "steam" must not claim "steam_app_123".
    function windowMatches(appId, key) {
        var id = String(appId || "").toLowerCase()
        if (id === "" || key.length < 2) return false
        return id === key || id.split(".").pop() === key
    }

    function windowsFor(item) {
        var key = appKey(item)
        if (key === "") return []
        var rows = context && context.compositor ? (context.compositor.windows || []) : []
        var result = []
        for (var index = 0; index < rows.length; index++) {
            var window = rows[index]
            if (window && windowMatches(window.app_id, key)) result.push(window)
        }
        return result
    }

    function activeWorkspaceIds() {
        var compositor = context ? context.compositor : null
        var rows = compositor ? (compositor.workspaces || []) : []
        var focusedOutput = compositor ? String(compositor.focusedOutputId || "") : ""
        var result = []
        for (var index = 0; index < rows.length; index++) {
            var workspace = rows[index]
            if (!workspace || !workspace.is_active) continue
            if (focusedOutput === "" || String(workspace.output || "") === focusedOutput)
                result.push(String(workspace.id))
        }
        return result
    }

    // Already focused, else on the active workspace of the focused output,
    // else the first match: a click should land where the user already is.
    function preferredWindow(item) {
        var windows = windowsFor(item)
        if (windows.length === 0) return null
        for (var index = 0; index < windows.length; index++)
            if (windows[index].is_focused) return windows[index]
        var visible = activeWorkspaceIds()
        for (var w = 0; w < windows.length; w++)
            if (visible.indexOf(String(windows[w].workspace_id)) >= 0) return windows[w]
        return windows[0]
    }

    function focusWindow(window) {
        if (!window || !context || !context.actions
                || typeof context.actions.windowFocus !== "function")
            return "unavailable"
        return context.actions.windowFocus(window.id)
    }

    // Left click: raise an existing window when there is one; otherwise let
    // the app handle Activate, which for most tray apps opens a fresh window.
    function activate(item) {
        var window = preferredWindow(item)
        if (window && focusWindow(window) === "ok") return "focused"
        if (!item || typeof item.activate !== "function") return "unsupported"
        item.activate()
        return "ok"
    }

    function secondaryActivate(item) {
        if (!item || typeof item.secondaryActivate !== "function") return "unsupported"
        item.secondaryActivate()
        return "ok"
    }

    function scroll(item, delta, horizontal) {
        if (!item || typeof item.scroll !== "function") return "unsupported"
        item.scroll(delta, Boolean(horizontal))
        return "ok"
    }
}
