import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell

    NiriState {
        id: niriState
    }

    function panelOpen(panel): bool {
        if (!panel) return false
        if (panel.centerVisible !== undefined) return panel.centerVisible
        if (panel.visible !== undefined) return panel.visible
        return false
    }

    function setPanelOpen(panel, open) {
        if (!panel) return
        if (panel.centerVisible !== undefined) panel.centerVisible = open
        else if (panel.visible !== undefined) panel.visible = open
    }

    function closeInteractivePanels(exceptPanel) {
        const panels = [audioMixer, bluetoothPanel, networkPanel, notificationCenter, batteryPanel]
        for (let i = 0; i < panels.length; i++) {
            if (panels[i] !== exceptPanel) setPanelOpen(panels[i], false)
        }
    }

    function togglePanel(panel): string {
        const next = !panelOpen(panel)
        closeInteractivePanels(panel)
        setPanelOpen(panel, next)
        return next ? "open" : "closed"
    }

    function panelByName(name) {
        const normalized = String(name || "").toLowerCase()
        if (normalized === "audio" || normalized === "mixer") return audioMixer
        if (normalized === "bluetooth" || normalized === "bt") return bluetoothPanel
        if (normalized === "network" || normalized === "wifi") return networkPanel
        if (normalized === "notifications" || normalized === "notification") return notificationCenter
        if (normalized === "power" || normalized === "battery") return batteryPanel
        if (normalized === "gallery") return devGallery
        return null
    }

    function panelAction(name, action): string {
        const panel = panelByName(name)
        if (!panel) return "unknown panel"

        const normalized = String(action || "toggle").toLowerCase()
        if (panel === devGallery) {
            if (normalized === "toggle") setPanelOpen(panel, !panelOpen(panel))
            else setPanelOpen(panel, normalized === "open" || normalized === "on" || normalized === "true" || normalized === "1")
            return panelOpen(panel) ? "open" : "closed"
        }

        if (normalized === "toggle") return togglePanel(panel)
        if (normalized === "open" || normalized === "on" || normalized === "true" || normalized === "1") {
            closeInteractivePanels(panel)
            setPanelOpen(panel, true)
            return "open"
        }
        if (normalized === "close" || normalized === "off" || normalized === "false" || normalized === "0") {
            setPanelOpen(panel, false)
            return "closed"
        }
        return "unknown action"
    }

    IpcHandler {
        target: "shell"

        function ping(): string {
            return "ok"
        }

        function status(): string {
            return JSON.stringify({
                barVisible: topBar.visible,
                niriEventStream: niriState.eventStreamRunning,
                screenCapture: niriState.screenCaptureActive,
                panels: {
                    audio: shell.panelOpen(audioMixer),
                    bluetooth: shell.panelOpen(bluetoothPanel),
                    network: shell.panelOpen(networkPanel),
                    notifications: shell.panelOpen(notificationCenter),
                    power: shell.panelOpen(batteryPanel),
                    gallery: shell.panelOpen(devGallery)
                }
            })
        }

        function bar(value: string): string {
            const normalized = String(value || "toggle").toLowerCase()
            if (normalized === "toggle") topBar.visible = !topBar.visible
            else topBar.visible = normalized === "on" || normalized === "open" || normalized === "true" || normalized === "1"
            return topBar.visible ? "on" : "off"
        }

        function panel(name: string, action: string): string {
            return shell.panelAction(name, action)
        }
    }

    TopBar {
        id: topBar
        niri: niriState
        audioPanel: audioMixer
        bluetoothPanel: bluetoothPanel
        networkPanel: networkPanel
        notificationPanel: notificationCenter
        powerPanel: batteryPanel
        panelCoordinator: shell
    }

    VolumeOsd {
        id: volumeOsd
    }
    BrightnessOsd {
        stackOffset: volumeOsd.shouldShow ? 40 + Theme.panelGap : 0
    }
    AudioMixer {
        id: audioMixer
        coordinator: shell
    }
    BluetoothPanel {
        id: bluetoothPanel
        coordinator: shell
    }
    NetworkPanel {
        id: networkPanel
        coordinator: shell
    }
    NotificationCenter {
        id: notificationCenter
        coordinator: shell
    }
    BatteryPanel {
        id: batteryPanel
        coordinator: shell
    }
    DevGallery {
        id: devGallery
    }
}
