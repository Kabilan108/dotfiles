import QtQuick
import Quickshell
import "services" as Services

ShellRoot {
    id: root
    property int checks: 0
    property var fakeContext: QtObject {}
    property var fakeAudio: QtObject { property int revision: 1; property real volume: 0.42; property bool muted: false; property var sink: ({ description: "Fixture speakers" }); property var source: ({ description: "Fixture mic" }); property var outputs: []; property var inputs: [] }
    property var fakeNetwork: QtObject {
        property int revision: 1
        property bool wifiEnabled: true
        property bool wiredConnected: false
        property var devices: []
        property var networks: [{ name: "fixture", connected: true, signalStrength: 0.8 }]
        property var vpns: []
        function scan() { return "ok" }
        function setWifiEnabled(value) { wifiEnabled = value; return "ok" }
        function activate(network) { return "ok" }
    }
    property var fakePower: QtObject { property int revision: 1; function setProfile(value) { return "ok" } }
    property var fakeBattery: QtObject { property int revision: 1; property var device: ({ isPresent: true, percentage: 0.56, timeToEmpty: 7200 }); property string state: "discharging" }
    property var fakeBluetooth: QtObject {
        property int revision: 1
        property bool enabled: true
        property var devices: [{ name: "Fixture headset", connected: true }]
        function setEnabled(value) { enabled = value; return "ok" }
        function scan() { return "ok" }
        function toggle(device) { return "ok" }
    }
    Services.AudioService { id: audio; context: root.fakeContext; model: root.fakeAudio }
    Services.NetworkService { id: network; context: root.fakeContext; model: root.fakeNetwork }
    Services.PowerService { id: power; context: root.fakeContext; model: root.fakePower }
    Services.BatteryService { id: battery; context: root.fakeContext; model: root.fakeBattery }
    Services.BluetoothService { id: bluetooth; context: root.fakeContext; model: root.fakeBluetooth }
    Services.AudioService { id: unavailableAudio; context: root.fakeContext; model: root.fakeAudio; forceUnavailable: true }
    Services.NetworkService { id: unavailableNetwork; context: root.fakeContext; model: root.fakeNetwork; forceUnavailable: true }
    Services.PowerService { id: unavailablePower; context: root.fakeContext; model: root.fakePower; forceUnavailable: true }
    Services.BatteryService { id: unavailableBattery; context: root.fakeContext; model: root.fakeBattery; forceUnavailable: true }
    Services.BluetoothService { id: unavailableBluetooth; context: root.fakeContext; model: root.fakeBluetooth; forceUnavailable: true }
    QtObject {
        id: fakeRegistry
        function get(id) {
            if (id === "stillsuit.audio") return audio
            if (id === "stillsuit.network") return network
            if (id === "stillsuit.battery") return battery
            if (id === "stillsuit.bluetooth") return bluetooth
            if (id === "stillsuit.power") return power
            return null
        }
    }
    QtObject {
        id: fakeWidgetContext
        property var theme: ({ geometry: { barHeight: 30, radius: 5 }, controls: { hover: { fill: "#313244" } }, colors: { text: { primary: "#cdd6f4" }, status: { error: "#f38ba8" } }, typography: { monospaceFamily: "sans", baseSize: 12 } })
        property var services: fakeRegistry
        property var actions: QtObject { function surfaceToggle(id, payload) { return "ok" } }
    }
    property var viewComponents: []
    Component.onCompleted: {
        var urls = ["plugins/builtin/audio/Widget.qml", "plugins/builtin/network/Widget.qml", "plugins/builtin/battery/Widget.qml", "plugins/builtin/bluetooth/Widget.qml"]
        for (var index = 0; index < urls.length; index++)
            viewComponents.push(Qt.createComponent(urls[index], Component.Asynchronous))
    }
    Timer {
        interval: 300
        running: true
        repeat: false
        onTriggered: {
            var services = [audio, network, power, battery, bluetooth]
            for (var index = 0; index < services.length; index++) {
                if (!services[index] || services[index].apiVersion !== "1") {
                    console.error("D3 fixture service failed " + index)
                    Qt.quit()
                    return
                }
            }

            var unavailable = [unavailableAudio, unavailableNetwork, unavailablePower,
                unavailableBattery, unavailableBluetooth]
            for (var unavailableIndex = 0; unavailableIndex < unavailable.length;
                    unavailableIndex++) {
                if (unavailable[unavailableIndex].available) {
                    console.error("D3 fixture unavailable state failed " + unavailableIndex)
                    Qt.quit()
                    return
                }
            }
            if (unavailableAudio.setVolume(0.5) !== "unavailable"
                    || unavailableNetwork.scan() !== "unavailable"
                    || unavailablePower.setProfile("balanced") !== "unavailable"
                    || unavailableBluetooth.scan() !== "unavailable") {
                console.error("D3 fixture unavailable action containment failed")
                Qt.quit()
                return
            }

            var widgetServices = [audio, network, battery, bluetooth]
            var viewCount = 0
            for (var viewIndex = 0; viewIndex < viewComponents.length; viewIndex++) {
                if (viewComponents[viewIndex].status !== Component.Ready) {
                    console.error("D3 fixture view failed "
                        + viewComponents[viewIndex].errorString())
                    Qt.quit()
                    return
                }
                for (var output = 0; output < 2; output++) {
                    var expectedOutputId = "fixture-output-" + output
                    var view = viewComponents[viewIndex].createObject(root, {
                        context: fakeWidgetContext,
                        service: widgetServices[viewIndex],
                        outputId: expectedOutputId
                    })
                    if (!view || view.service !== widgetServices[viewIndex]
                            || view.outputId !== expectedOutputId) {
                        console.error("D3 fixture singleton injection failed " + viewIndex)
                        Qt.quit()
                        return
                    }
                    viewCount++
                }
            }
            if (audio.volume !== 0.42 || !network.connectedNetwork
                    || battery.percentage !== 56 || !bluetooth.connected
                    || viewCount !== 8) {
                console.error("D3 fixture state propagation failed")
                Qt.quit()
                return
            }
            console.log("D3_FIXTURE_OK singleton=5 outputs=2 unavailable=contained argv=fixed")
            Qt.quit()
        }
    }
}
