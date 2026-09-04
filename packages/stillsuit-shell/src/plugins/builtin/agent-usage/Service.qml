import QtQuick
import Quickshell.Io

QtObject {
    id: root

    required property var context
    property var model: null
    property var snapshot: ({
        accounts: [],
        summary: ({ accountCount: 0, readyCount: 0, maxUsed: -1 }),
        updatedAt: ""
    })
    property bool refreshing: false
    property bool refreshQueued: false
    property string lastError: ""
    property int localRevision: 0

    readonly property string apiVersion: "1"
    readonly property var values: context && context.settings
        && context.settings.values ? context.settings.values : ({})
    readonly property string helperPath: String(values.helperPath || "")
    readonly property string homeDir: String(values.homeDir || "")
    readonly property string shadowRoot: String(values.shadowRoot || "")
    readonly property bool includeDefaults: values.includeDefaults !== false
    readonly property var configuredAccounts: Array.isArray(values.accounts)
        ? values.accounts : []
    readonly property int refreshIntervalSec: Math.max(60,
        Number(values.refreshIntervalSec || 300))
    readonly property bool helperReady: model === null
        && helperPath.charAt(0) === "/" && helper.running
    readonly property bool available: model !== null || helperReady
    readonly property var accounts: model
        ? model.accounts || []
        : snapshot.accounts || []
    readonly property var summary: model
        ? model.summary || ({ accountCount: accounts.length, readyCount: 0, maxUsed: -1 })
        : snapshot.summary || ({ accountCount: accounts.length, readyCount: 0, maxUsed: -1 })
    readonly property int accountCount: Number(summary.accountCount || accounts.length || 0)
    readonly property int readyCount: Number(summary.readyCount || 0)
    readonly property real maxUsed: Number(summary.maxUsed === undefined ? -1 : summary.maxUsed)
    readonly property string updatedAt: model
        ? String(model.updatedAt || "")
        : String(snapshot.updatedAt || "")
    readonly property int revision: (model && model.revision !== undefined
        ? Number(model.revision) : 0) + localRevision

    property Process helper: Process {
        command: root.helperPath !== "" ? [root.helperPath] : []
        stdinEnabled: true
        running: root.model === null && root.helperPath.charAt(0) === "/"
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) { root._handleResponse(line) }
        }
        onStarted: root.refresh(false)
        onExited: function(exitCode) {
            if (root.model === null) {
                root.refreshing = false
                root.lastError = "Agent usage helper exited with status " + exitCode
                root.localRevision++
            }
        }
    }

    property Timer refreshTimer: Timer {
        interval: root.refreshIntervalSec * 1000
        repeat: true
        running: root.helperReady
        onTriggered: root.refresh(false)
    }

    function _request(force) {
        return {
            operation: force ? "refresh" : "snapshot",
            force: Boolean(force),
            homeDir: homeDir,
            shadowRoot: shadowRoot,
            includeDefaults: includeDefaults,
            accounts: configuredAccounts
        }
    }

    function _handleResponse(line) {
        var response
        try {
            response = JSON.parse(String(line || ""))
        } catch (error) {
            lastError = "Agent usage helper returned invalid data"
            refreshing = false
            localRevision++
            return
        }
        if (!response || response.schemaVersion !== 1
                || response.operation !== "snapshot"
                || !Array.isArray(response.accounts)) {
            lastError = String(response && response.error
                ? response.error : "Agent usage helper returned an invalid snapshot")
            refreshing = false
            localRevision++
            return
        }
        snapshot = response
        lastError = ""
        refreshing = false
        localRevision++
        if (refreshQueued) {
            refreshQueued = false
            refresh(true)
        }
    }

    function refresh(force) {
        if (model && typeof model.refresh === "function") {
            model.refresh(Boolean(force))
            return "ok"
        }
        if (model)
            return "ok"
        if (!helperReady)
            return "unavailable"
        if (refreshing) {
            refreshQueued = refreshQueued || Boolean(force)
            return "queued"
        }
        refreshing = true
        lastError = ""
        helper.write(JSON.stringify(_request(force)) + "\n")
        localRevision++
        return "started"
    }

    function statusFor(account) {
        if (!account)
            return "unavailable"
        return String(account.status || "unavailable")
    }

    function statusRole(account) {
        var status = statusFor(account)
        if (status === "ready")
            return "success"
        if (status === "refresh-required" || status === "signed-out"
                || status === "empty")
            return "warning"
        return "danger"
    }
}
