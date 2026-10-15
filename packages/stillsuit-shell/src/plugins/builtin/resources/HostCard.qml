pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Stillsuit.Ui as Ui

ColumnLayout {
    id: root
    required property var theme
    required property var service
    required property string hostName
    required property bool remote
    required property var snapshot
    required property bool refreshing
    required property string errorMessage
    required property double updatedAt
    readonly property int unit: theme.metrics.spaceUnit
    readonly property var sample: snapshot || ({})
    readonly property var gpus: remote ? sample.gpus || [] : []
    readonly property bool stale: remote && service.remoteStale
    readonly property bool degraded: errorMessage !== "" || stale
    readonly property real labelWidth: Math.ceil(labelMetrics.advanceWidth)
    readonly property real detailWidth: Math.ceil(detailMetrics.advanceWidth)
    readonly property real percentWidth: Math.ceil(percentMetrics.advanceWidth)
    spacing: unit * 2

    TextMetrics {
        id: labelMetrics
        font.family: root.theme.typography.bodyFamily
        font.pixelSize: root.theme.typography.baseSize
        text: "Memory"
    }
    TextMetrics {
        id: detailMetrics
        font.family: root.theme.typography.monoFamily
        font.pixelSize: root.theme.typography.captionSize
        text: "000.0 / 000.0 GiB"
    }
    TextMetrics {
        id: percentMetrics
        font.family: root.theme.typography.monoFamily
        font.pixelSize: root.theme.typography.baseSize
        font.weight: root.theme.typography.weightMedium
        text: "100%"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: root.unit * 2
        HostIcon {
            theme: root.theme
            server: root.remote
            color: root.theme.semantic.content.secondary
            Accessible.name: root.remote ? "Server" : "Laptop"
        }
        Ui.ShellText {
            theme: root.theme
            text: root.hostName
            sizeRole: "label"
        }
        Item { Layout.fillWidth: true }
        Rectangle {
            implicitWidth: root.unit * 1.5
            implicitHeight: implicitWidth
            radius: width / 2
            color: root.degraded ? root.theme.semantic.status.warning
                : root.refreshing && !root.snapshot ? root.theme.semantic.content.muted
                : root.theme.semantic.status.success
        }
        Ui.ShellText {
            theme: root.theme
            text: root.remote ? root.refreshing ? "Reading…"
                    : (root.stale ? "Stale · " : "") + root.service.age(root.updatedAt)
                : "Live"
            role: root.degraded ? "warning" : "muted"
            sizeRole: "caption"
        }
    }

    Ui.ShellStatus {
        Layout.fillWidth: true
        visible: root.errorMessage !== ""
        theme: root.theme
        status: "warning"
        label: root.errorMessage + (root.snapshot ? " Showing the last sample." : "")
        wrap: true
        maximumLines: 3
    }
    Ui.ShellText {
        Layout.fillWidth: true
        visible: !root.snapshot && root.errorMessage === ""
        theme: root.theme
        text: "Reading performance…"
        role: "muted"
        sizeRole: "caption"
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.snapshot !== null
        spacing: root.unit * 2
        UsageMeter {
            objectName: "host-cpu"
            Layout.fillWidth: true
            theme: root.theme
            service: root.service
            label: "CPU"
            percent: root.sample.cpuPercent
            detail: root.temperature(root.sample.cpuTemperature)
            labelWidth: root.labelWidth
            detailWidth: root.detailWidth
            percentWidth: root.percentWidth
        }
        UsageMeter {
            objectName: "host-memory"
            Layout.fillWidth: true
            theme: root.theme
            service: root.service
            label: "Memory"
            percent: root.sample.memoryPercent
            detail: root.memory(root.sample.memoryUsedBytes, root.sample.memoryTotalBytes)
            labelWidth: root.labelWidth
            detailWidth: root.detailWidth
            percentWidth: root.percentWidth
        }
        Repeater {
            model: root.gpus
            delegate: ColumnLayout {
                id: gpu
                required property var modelData
                Layout.fillWidth: true
                Layout.topMargin: root.unit
                spacing: root.unit * 2
                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.unit * 2
                    Ui.ShellSectionLabel {
                        Layout.maximumWidth: implicitWidth
                        Layout.fillWidth: true
                        theme: root.theme
                        text: String(gpu.modelData.name || "GPU").replace(/^NVIDIA GeForce\s+/, "")
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: root.theme.semantic.outline.subtle
                    }
                }
                UsageMeter {
                    objectName: "host-gpu-compute"
                    Layout.fillWidth: true
                    theme: root.theme
                    service: root.service
                    label: "GPU"
                    percent: gpu.modelData.percent
                    detail: root.temperature(gpu.modelData.temperature)
                    labelWidth: root.labelWidth
                    detailWidth: root.detailWidth
                    percentWidth: root.percentWidth
                }
                UsageMeter {
                    objectName: "host-gpu-vram"
                    Layout.fillWidth: true
                    theme: root.theme
                    service: root.service
                    label: "VRAM"
                    percent: root.vramPercent(gpu.modelData)
                    detail: root.memory(gpu.modelData.usedBytes, gpu.modelData.totalBytes)
                    labelWidth: root.labelWidth
                    detailWidth: root.detailWidth
                    percentWidth: root.percentWidth
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: root.unit * 3.5
            Ui.ShellText {
                theme: root.theme
                text: "Pressure"
                sizeRole: "caption"
                role: "muted"
                Accessible.description: "Time waiting for a resource over the last ten seconds"
            }
            Item { Layout.fillWidth: true }
            Repeater {
                model: [ {label: "cpu", key: "cpu"}, {label: "mem", key: "memory"}, {label: "io", key: "io"} ]
                delegate: Row {
                    id: pressureItem
                    required property var modelData
                    spacing: root.unit
                    Ui.ShellText {
                        theme: root.theme
                        text: pressureItem.modelData.label
                        sizeRole: "caption"
                        monospace: true
                        role: "muted"
                    }
                    Ui.ShellText {
                        theme: root.theme
                        text: root.pressure(pressureItem.modelData.key)
                        sizeRole: "caption"
                        monospace: true
                        role: root.pressureRole(pressureItem.modelData.key)
                    }
                }
            }
        }
    }
    function temperature(value) {
        return typeof value === "number" && isFinite(value) ? Math.round(value) + "°C" : ""
    }
    function memory(used, total) {
        if (typeof used !== "number" || typeof total !== "number" || total <= 0)
            return ""
        return (used / 1073741824).toFixed(1) + " / " + (total / 1073741824).toFixed(1) + " GiB"
    }
    function vramPercent(gpu) {
        return typeof gpu.usedBytes === "number" && typeof gpu.totalBytes === "number"
            && gpu.totalBytes > 0 ? gpu.usedBytes / gpu.totalBytes * 100 : null
    }
    function pressure(key) {
        var value = (sample.pressure || ({}))[key]
        return typeof value === "number" && isFinite(value) ? value.toFixed(1) + "%" : "--"
    }
    function pressureRole(key) {
        var value = (sample.pressure || ({}))[key]
        if (typeof value !== "number" || !isFinite(value) || value < 1)
            return "muted"
        return value >= 10 ? "warning" : "secondary"
    }
}
