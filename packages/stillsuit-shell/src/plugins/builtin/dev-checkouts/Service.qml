import QtQuick
import Quickshell
import Quickshell.Io

// Polls `dev co list --json` on sietch through the fixed helper and owns the
// last good checkout list. Views only read it and call refresh()/openLink().
QtObject {
    id: root

    required property var context
    readonly property string apiVersion: "1"

    readonly property var values: context && context.settings
        && context.settings.values ? context.settings.values : ({})
    readonly property string helperPath: String(values.helperPath || "")
    // Qt.openUrlExternally finds no browser from the shell's service
    // environment, so links go through the fixed desktop opener.
    readonly property string openHelperPath: String(values.openHelperPath || "")
    readonly property int refreshIntervalSec: Math.max(30,
        Number(values.refreshIntervalSec || 90))
    // Settings lists arrive as QVariantList, which fails Array.isArray in Qt.
    readonly property var primaryLinks: values.primaryLinks
        && typeof values.primaryLinks === "object"
        && typeof values.primaryLinks.length === "number"
        ? Array.prototype.slice.call(values.primaryLinks) : ["dashboard", "dask"]
    readonly property bool available: helperPath.charAt(0) === "/"

    property var checkouts: []
    property string lastError: ""
    property string updatedAt: ""
    property bool refreshing: false
    property bool loaded: false

    readonly property var running: checkouts.filter(function(c) { return c.running === true })
    readonly property var idle: checkouts.filter(function(c) { return c.running !== true })
    readonly property int runningCount: running.length

    property Process helper: Process {
        command: root.available ? [root.helperPath] : []
        stdout: StdioCollector {
            id: helperOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: helperErr
            waitForEnd: true
        }
        onExited: function(exitCode) {
            root.refreshing = false
            if (exitCode !== 0) {
                var detail = helperErr.text.trim().split("\n").filter(function(line) {
                    return line !== ""
                }).pop() || ""
                root.lastError = detail !== "" ? detail : "Status helper exited " + exitCode
                return
            }
            root._apply(helperOut.text)
        }
    }

    property Timer refreshTimer: Timer {
        interval: root.refreshIntervalSec * 1000
        repeat: true
        running: root.available
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function refresh() {
        if (!available)
            return "unavailable"
        if (refreshing)
            return "queued"
        refreshing = true
        helper.running = true
        return "started"
    }

    function _apply(text) {
        var payload
        try {
            payload = JSON.parse(String(text || ""))
        } catch (error) {
            lastError = "Status helper returned invalid JSON"
            return
        }
        if (!payload || payload.schema_version !== 1 || !Array.isArray(payload.checkouts)) {
            lastError = payload && payload.error
                ? String(payload.error)
                : "Unsupported dev co list schema"
            return
        }
        checkouts = payload.checkouts.slice().sort(_byRecentUse)
        lastError = ""
        loaded = true
        updatedAt = new Date().toISOString()
    }

    function _byRecentUse(a, b) {
        return String(b.last_used || "").localeCompare(String(a.last_used || ""))
    }

    function title(checkout) {
        return String(checkout.project || checkout.branch || checkout.name)
    }

    function subtitle(checkout) {
        var parts = []
        if (checkout.instance !== null && checkout.instance !== undefined)
            parts.push("#" + checkout.instance)
        if (checkout.project && checkout.branch)
            parts.push(checkout.branch)
        else if (!checkout.project && checkout.branch)
            parts.push(checkout.name)
        if (checkout.checkpoint && checkout.checkpoint !== "default")
            parts.push("db " + checkout.checkpoint)
        return parts.join(" · ")
    }

    function liveLinks(checkout) {
        return (checkout.links || []).filter(function(link) { return link.state === "running" })
    }

    function isPrimary(link) {
        return primaryLinks.indexOf(link.name) !== -1
    }

    function linkLabel(link) {
        var labels = { dashboard: "Dashboard", dask: "Dask", query: "Query", iam: "IAM",
            hub: "Hub", clara: "Clara" }
        return labels[link.name] || link.name
    }

    function openLink(link) {
        var url = link ? String(link.url || "") : ""
        if (!/^https?:\/\//.test(url))
            return "invalid"
        if (openHelperPath.charAt(0) !== "/") {
            lastError = "Set openHelperPath to open links"
            return "unavailable"
        }
        Quickshell.execDetached([openHelperPath, url])
        return "started"
    }
}
