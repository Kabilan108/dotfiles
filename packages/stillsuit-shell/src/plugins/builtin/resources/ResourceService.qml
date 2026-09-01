import QtQuick
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
        for (var index = 1; index < firstLine.length; index++) {
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
}
