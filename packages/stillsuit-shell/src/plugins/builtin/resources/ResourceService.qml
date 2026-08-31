import QtQuick
import Quickshell.Io

QtObject {
    id: root

    required property var context
    property int cpuPercent: 0
    property int memoryPercent: 0
    property double previousTotal: 0
    property double previousIdle: 0

    property FileView statFile: FileView {
        id: statFile
        path: "/proc/stat"
        preload: false
        blockLoading: true
        blockAllReads: true
        printErrors: false
    }

    property FileView memoryFile: FileView {
        id: memoryFile
        path: "/proc/meminfo"
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
        updateCpu(statFile.text())
        updateMemory(memoryFile.text())
    }

    function updateCpu(raw) {
        var firstLine = String(raw || "").split("\n")[0].trim().split(/\s+/)
        if (firstLine.length < 5 || firstLine[0] !== "cpu")
            return
        var total = 0
        for (var index = 1; index < firstLine.length; index++)
            total += Number(firstLine[index] || 0)
        var idle = Number(firstLine[4] || 0) + Number(firstLine[5] || 0)
        if (previousTotal > 0 && total > previousTotal) {
            var totalDelta = total - previousTotal
            cpuPercent = Math.round(Math.max(0, Math.min(100, 100 * (totalDelta - (idle - previousIdle)) / totalDelta)))
        }
        previousTotal = total
        previousIdle = idle
    }

    function updateMemory(raw) {
        var total = memoryValue(raw, "MemTotal")
        var available = memoryValue(raw, "MemAvailable")
        if (total > 0)
            memoryPercent = Math.round(Math.max(0, Math.min(100, 100 * (total - available) / total)))
    }

    function memoryValue(raw, key) {
        var lines = String(raw || "").split("\n")
        for (var index = 0; index < lines.length; index++) {
            var parts = lines[index].split(":")
            if (parts.length === 2 && parts[0] === key)
                return Number(parts[1].trim().split(/\s+/)[0] || 0)
        }
        return 0
    }
}
