import QtQuick
import Quickshell.Io
import "../../../services" as Services

Services.BluetoothService {
    id: root

    property Process managerProcess: Process {
        command: ["blueman-manager"]
        onExited: function(exitCode) {
            if (exitCode !== 0)
                root.lastError = "Could not open Bluetooth settings"
        }
    }

    function openManager() {
        lastError = ""
        if (model && typeof model.openManager === "function")
            return _finishImmediate(model.openManager(), "manager")
        if (managerProcess.running)
            return "busy"
        managerProcess.running = true
        return "pending"
    }
}
