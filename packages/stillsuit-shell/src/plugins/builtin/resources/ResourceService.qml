import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    required property var context
    readonly property string apiVersion: "1"
    property int revision: 0
    property int cpuPercent: 0
    property int memoryPercent: 0
    property double previousTotal: 0
    property double previousIdle: 0
    property string statPath: "/proc/stat"
    property string memoryPath: "/proc/meminfo"
    property var fleet: ({})
    readonly property string localName: String(fleet.self || "This machine")
    readonly property string remoteName: _remoteName()
    readonly property bool remoteAvailable: remoteName !== ""
    readonly property string pythonPath: "/etc/profiles/per-user/" + Quickshell.env("USER") + "/bin/python3"
    property var localSnapshot: null
    property var remoteSnapshot: null
    property double localUpdatedAt: 0
    property double remoteUpdatedAt: 0
    property double remoteAttemptAt: 0
    property bool localRefreshing: false
    property bool remoteRefreshing: false
    property string localError: ""
    property string remoteError: ""
    property var panelOutputs: []
    property string hoveredOutputId: ""
    property string tooltipOutputId: ""
    readonly property double now: clock.date.getTime()
    readonly property bool remoteStale: remoteUpdatedAt > 0 && now - remoteUpdatedAt > 30000

    property SystemClock clock: SystemClock { precision: SystemClock.Seconds }

    property FileView fleetFile: FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/fleet/fleet.json"
        preload: false
        blockLoading: true
        blockAllReads: true
        printErrors: false
    }

    property FileView collectorFile: FileView {
        path: decodeURIComponent(String(Qt.resolvedUrl("collect.py")).replace(/^file:\/\//, ""))
        preload: false
        blockLoading: true
        blockAllReads: true
        printErrors: false
    }

    property Process localCollector: Process {
        stdout: StdioCollector { id: localOut; waitForEnd: true }
        onRunningChanged: if (!running) Qt.callLater(function() {
            // FailedToStart has no exited signal. Normal exits finish first.
            if (root.localRefreshing && !root.localCollector.running) {
                localTimeout.stop()
                root.localRefreshing = false
                root.localError = "Couldn't start the local performance collector"
            }
        })
        onExited: function(code) {
            localTimeout.stop()
            root.localRefreshing = false
            if (code === 0 && root.applySnapshot(localOut.text, false))
                return
            if (root.localError === "")
                root.localError = "Couldn't read local performance data"
        }
    }

    property Process remoteCollector: Process {
        stdout: StdioCollector { id: remoteOut; waitForEnd: true }
        onRunningChanged: if (!running) Qt.callLater(function() {
            if (root.remoteRefreshing && !root.remoteCollector.running) {
                remoteTimeout.stop()
                root.remoteRefreshing = false
                root.remoteError = "Couldn't start the PC performance request"
            }
        })
        // Send the collector over stdin, so the PC needs no installation or repo sync.
        onStarted: {
            root.remoteCollector.write(root.collectorFile.text() + "\n")
            root.remoteCollector.stdinEnabled = false
        }
        onExited: function(code) {
            remoteTimeout.stop()
            root.remoteRefreshing = false
            if (code === 0 && root.applySnapshot(remoteOut.text, true))
                return
            if (root.remoteError === "")
                root.remoteError = "Couldn't read " + root.remoteName + ". Try refreshing."
        }
    }

    property Timer localTimeout: Timer {
        interval: 6000
        onTriggered: {
            root.localError = "Local performance request timed out"
            root.localCollector.signal(9)
        }
    }

    property Timer remoteTimeout: Timer {
        interval: 12000
        onTriggered: {
            root.remoteError = root.remoteName + " didn't respond. Try refreshing."
            root.remoteCollector.signal(9)
        }
    }

    property Timer detailTimer: Timer {
        interval: 3000
        running: root.panelOutputs.length > 0
        repeat: true
        onTriggered: root.refreshLocal()
    }

    property Timer hoverDelay: Timer {
        interval: 500
        onTriggered: {
            root.tooltipOutputId = root.hoveredOutputId
            root.hoverRefresh()
        }
    }

    Component.onCompleted: {
        fleetFile.reload()
        try { fleet = JSON.parse(fleetFile.text()) } catch (error) { fleet = ({}) }
    }

    property FileView statFile: FileView {
        id: statFile
        path: root.statPath
        preload: false
        blockLoading: true
        blockAllReads: true
        printErrors: false
    }

    property FileView memoryFile: FileView {
        id: memoryFile
        path: root.memoryPath
        preload: false
        blockLoading: true
        blockAllReads: true
        printErrors: false
    }

    property Timer refreshTimer: Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function refresh() {
        statFile.reload()
        memoryFile.reload()
        updateCpu(statFile.text())
        updateMemory(memoryFile.text())
    }

    function updateCpu(raw) {
        var firstLine = String(raw || "").split("\n")[0].trim().split(/\s+/)
        if (firstLine.length < 5 || firstLine[0] !== "cpu")
            return
        var total = 0
        // guest and guest_nice are already included in user and nice.
        for (var index = 1; index < Math.min(firstLine.length, 9); index++) {
            var sample = Number(firstLine[index])
            if (!isFinite(sample))
                return
            total += sample
        }
        var idle = Number(firstLine[4] || 0) + Number(firstLine[5] || 0)
        if (!isFinite(idle))
            return
        if (previousTotal > 0 && total > previousTotal) {
            var totalDelta = total - previousTotal
            var nextPercent = Math.round(Math.max(0, Math.min(100,
                100 * (totalDelta - (idle - previousIdle)) / totalDelta)))
            if (nextPercent !== cpuPercent) {
                cpuPercent = nextPercent
                revision++
            }
        }
        previousTotal = total
        previousIdle = idle
    }

    function updateMemory(raw) {
        var total = memoryValue(raw, "MemTotal")
        var available = memoryValue(raw, "MemAvailable")
        if (total > 0 && available >= 0 && available <= total) {
            var nextPercent = Math.round(Math.max(0, Math.min(100,
                100 * (total - available) / total)))
            if (nextPercent !== memoryPercent) {
                memoryPercent = nextPercent
                revision++
            }
        }
    }

    function memoryValue(raw, key) {
        var lines = String(raw || "").split("\n")
        for (var index = 0; index < lines.length; index++) {
            var parts = lines[index].split(":")
            if (parts.length === 2 && parts[0] === key)
                return Number(parts[1].trim().split(/\s+/)[0] || 0)
        }
        return -1
    }

    function usageBand(value) {
        if (value === undefined || value === null || value === "")
            return ""
        var percent = Number(value)
        if (!isFinite(percent))
            return ""
        if (percent >= 90)
            return "critical"
        if (percent >= 75)
            return "high"
        if (percent >= 60)
            return "elevated"
        return "normal"
    }

    function _remoteName() {
        var self = fleet.machines && fleet.machines[fleet.self]
        var allowed = self ? self.canAccess || [] : []
        for (var index = 0; index < allowed.length; index++) {
            var name = String(allowed[index])
            if (/^[a-z][a-z0-9-]*$/.test(name) && fleet.machines[name]
                    && fleet.machines[name].role === "agent-worker")
                return name
        }
        return ""
    }

    function setPanelOpen(output, opened) {
        var next = panelOutputs.filter(function(id) { return id !== output })
        if (opened)
            next.push(output)
        panelOutputs = next
        if (opened)
            refreshDetails()
    }

    function hoverRefresh() {
        if (Date.now() - localUpdatedAt > 5000)
            refreshLocal()
        if (remoteAvailable && Date.now() - remoteAttemptAt > 30000
                && Date.now() - remoteUpdatedAt > 30000)
            refreshRemote()
    }

    function setHovered(output, hovered) {
        if (hovered) {
            hoveredOutputId = output
            tooltipOutputId = ""
            hoverDelay.restart()
        } else if (hoveredOutputId === output) {
            hoveredOutputId = ""
            tooltipOutputId = ""
            hoverDelay.stop()
        }
    }

    function refreshDetails() {
        refresh()
        refreshLocal()
        refreshRemote()
    }

    function refreshLocal() {
        if (localRefreshing)
            return "busy"
        collectorFile.reload()
        if (!collectorFile.text()) {
            localError = "Performance collector unavailable"
            return "unavailable"
        }
        localError = ""
        localRefreshing = true
        localCollector.command = [pythonPath, "-c", collectorFile.text()]
        localTimeout.restart()
        localCollector.running = true
        return "started"
    }

    function refreshRemote() {
        if (!remoteAvailable)
            return "unavailable"
        if (remoteRefreshing)
            return "busy"
        collectorFile.reload()
        if (!collectorFile.text()) {
            remoteError = "Performance collector unavailable"
            return "unavailable"
        }
        remoteAttemptAt = Date.now()
        remoteError = ""
        remoteRefreshing = true
        remoteCollector.command = ["/run/current-system/sw/bin/ssh", "-T",
            "-o", "BatchMode=yes", "-o", "ConnectTimeout=5", "-o", "ConnectionAttempts=1",
            "-o", "ServerAliveInterval=3", "-o", "ServerAliveCountMax=1",
            remoteName + "-agent", "python3 -"]
        remoteCollector.stdinEnabled = true
        remoteTimeout.restart()
        remoteCollector.running = true
        return "started"
    }

    function applySnapshot(raw, remote) {
        var data
        try { data = JSON.parse(String(raw)) } catch (error) { return false }
        if (!data || data.schemaVersion !== 1 || !validPercent(data.cpuPercent)
                || !validPercent(data.memoryPercent) || !Array.isArray(data.load)
                || data.load.length !== 3 || !data.pressure || !Array.isArray(data.gpus))
            return false
        if (remote) {
            remoteSnapshot = data
            remoteUpdatedAt = Date.now()
            remoteError = ""
        } else {
            localSnapshot = data
            localUpdatedAt = Date.now()
            localError = ""
        }
        revision++
        return true
    }

    function validPercent(value) {
        return typeof value === "number" && isFinite(value) && value >= 0 && value <= 100
    }

    function percent(value) {
        return validPercent(value) ? Math.round(value) + "%" : "--"
    }

    function bytes(value) {
        if (typeof value !== "number" || !isFinite(value) || value < 0)
            return "--"
        var units = ["B", "KiB", "MiB", "GiB", "TiB"]
        var index = 0
        while (value >= 1024 && index < units.length - 1) { value /= 1024; index++ }
        return value.toFixed(index > 0 ? 1 : 0) + " " + units[index]
    }

    function age(updatedAt) {
        if (!updatedAt)
            return "No sample yet"
        var seconds = Math.max(0, Math.floor((now - updatedAt) / 1000))
        return seconds < 60 ? seconds + "s ago" : Math.floor(seconds / 60) + "m ago"
    }

    function headline(remote) {
        var data = remote ? remoteSnapshot : localSnapshot
        if (remote && !data)
            return remoteRefreshing ? "Reading PC…" : remoteError ? "PC unavailable" : "Open to read PC"
        var text = "CPU " + percent(remote ? data.cpuPercent : cpuPercent)
            + " · MEM " + percent(remote ? data.memoryPercent : memoryPercent)
        if (remote && (remoteError || remoteRefreshing))
            text += " · " + (remoteError ? "unavailable" : "refreshing")
        return text
    }
}
