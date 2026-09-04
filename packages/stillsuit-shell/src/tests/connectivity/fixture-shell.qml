import QtQuick
import Quickshell
import "services" as Services
import "ui" as Ui

ShellRoot {
    id: root

    property int checks: 0
    property string secret: "fixture-personal-secret"
    property var events: []
    property var fakeContext: QtObject {
        property var settings: QtObject {
            property var values: ({ networkHelperPath: "" })
        }
    }

    property var openNetwork: ({
        id: "open",
        name: "Cafe",
        kind: "open",
        known: false,
        connected: false,
        signal: 72
    })
    property var savedNetwork: ({
        id: "saved",
        uuid: "saved-uuid",
        name: "Home",
        kind: "personal",
        known: true,
        connected: false,
        signal: 88
    })
    property var personalNetwork: ({
        id: "personal",
        name: "Personal",
        kind: "personal",
        known: false,
        connected: false,
        signal: 61
    })
    property var enterpriseNetwork: ({
        id: "enterprise",
        uuid: "enterprise-uuid",
        name: "Enterprise",
        kind: "enterprise",
        known: true,
        connected: false,
        signal: 90
    })
    property var mobergVpn: ({
        uuid: "moberg-uuid",
        name: "MobergAnalytics",
        active: false,
        toggleAllowed: true,
        readOnly: false
    })
    property var otherVpn: ({
        uuid: "other-uuid",
        name: "Other VPN",
        active: true,
        toggleAllowed: false,
        readOnly: true
    })

    property var fakeNetwork: QtObject {
        property int revision: 1
        property bool wifiEnabled: true
        property bool wiredConnected: true
        property string wiredName: "Fixture Ethernet"
        property var networks: [root.openNetwork, root.savedNetwork,
            root.personalNetwork, root.enterpriseNetwork]
        property var vpns: [root.mobergVpn, root.otherVpn]
        property var tailscale: ({
            available: true,
            status: "running",
            ip: "100.64.0.8",
            hostName: "fixture-host",
            dnsName: "fixture-host.fixture.ts.net",
            services: ["siren.fixture.ts.net", "vault.fixture.ts.net"]
        })
        property int scans: 0
        property int editorHandoffs: 0
        property int vpnToggles: 0
        property string copiedTailscaleField: ""
        property string copiedTailscaleService: ""
        property bool failNext: false

        function scan() {
            scans++
            return "ok"
        }

        function setWifiEnabled(value) {
            wifiEnabled = value
            return "ok"
        }

        function copyTailscale(field, serviceName) {
            copiedTailscaleField = field
            copiedTailscaleService = serviceName || ""
            return "ok"
        }

        function join(network, password) {
            if (failNext) {
                failNext = false
                return ({ status: "error", error: "wrong password" })
            }
            if (network.kind === "personal" && !network.known
                    && password !== root.secret)
                return ({ status: "error", error: "wrong password" })
            network.connected = true
            return "ok"
        }

        function disconnect(network) {
            network.connected = false
            return "ok"
        }

        function openEditor(mode, network) {
            editorHandoffs++
            root.events = root.events.concat(["editor:" + mode])
            return "ok"
        }

        function toggleVpn(vpn) {
            vpn.active = !vpn.active
            vpnToggles++
            return "ok"
        }
    }

    Services.NetworkService {
        id: network
        context: root.fakeContext
        model: root.fakeNetwork
    }

    property var connectedDevice: QtObject {
        property string address: "AA:00:00:00:00:01"
        property string name: "Connected headset"
        property bool connected: true
        property bool paired: true
        property bool bonded: true
        property bool trusted: true
        property bool batteryAvailable: true
        property real battery: 0.63
        property string state: "connected"
    }
    property var pairedDevice: QtObject {
        property string address: "AA:00:00:00:00:02"
        property string name: "Paired headset"
        property bool connected: false
        property bool paired: true
        property bool bonded: true
        property bool trusted: true
        property bool batteryAvailable: false
        property real battery: 0
        property string state: "disconnected"
    }
    property var availableDevice: QtObject {
        property string address: "AA:00:00:00:00:03"
        property string name: "Available headset"
        property bool connected: false
        property bool paired: false
        property bool bonded: false
        property bool trusted: false
        property bool batteryAvailable: false
        property real battery: 0
        property string state: "disconnected"
    }
    property var failedDevice: QtObject {
        property string address: "AA:00:00:00:00:04"
        property string name: "Failed headset"
        property bool connected: false
        property bool paired: true
        property bool bonded: true
        property bool trusted: true
        property bool batteryAvailable: false
        property real battery: 0
        property string state: "disconnected"
    }

    property var fakeBluetooth: QtObject {
        property int revision: 1
        property bool enabled: true
        property bool scanning: false
        property bool failNext: false
        property var devices: [root.connectedDevice, root.pairedDevice,
            root.availableDevice, root.failedDevice]

        function setEnabled(value) {
            enabled = value
            return "ok"
        }

        function scan() {
            scanning = true
            return "ok"
        }

        function stopScan() {
            scanning = false
            return "ok"
        }

        function connectDevice(device) {
            if (failNext) {
                failNext = false
                return ({ status: "error", error: "BlueZ rejected connection" })
            }
            root.events = root.events.concat(["connect:" + device.address])
            device.paired = true
            device.bonded = true
            device.trusted = true
            device.connected = true
            device.state = "connected"
            return "ok"
        }

        function disconnectDevice(device) {
            root.events = root.events.concat(["disconnect:" + device.address])
            device.connected = false
            device.state = "disconnected"
            return "ok"
        }

        function forgetDevice(device) {
            root.events = root.events.concat(["forget:" + device.address])
            device.connected = false
            device.paired = false
            device.bonded = false
            device.state = "disconnected"
            return "ok"
        }

        function makeDefaultAudio(device) {
            root.events = root.events.concat(["audio:" + device.address])
            return "ok"
        }
    }

    Services.BluetoothService {
        id: bluetooth
        context: root.fakeContext
        model: root.fakeBluetooth
    }

    property var viewComponents: []

    Component.onCompleted: {
        var urls = [
            "plugins/builtin/network/Widget.qml",
            "plugins/builtin/bluetooth/Widget.qml",
            "plugins/builtin/bluetooth/Service.qml"
        ]
        for (var index = 0; index < urls.length; index++)
            viewComponents.push(Qt.createComponent(urls[index], Component.Asynchronous))
    }

    function expect(condition, message) {
        checks++
        if (!condition)
            throw new Error(message)
    }

    Timer {
        interval: 50
        running: true
        repeat: false

        onTriggered: {
          try {
            for (var componentIndex = 0; componentIndex < viewComponents.length;
                    componentIndex++) {
                expect(viewComponents[componentIndex].status === Component.Ready,
                    "connectivity view failed: "
                        + viewComponents[componentIndex].errorString())
            }
            expect(network.available && network.wifiEnabled && network.wiredConnected,
                "network owner state was not exposed")
            expect(network.scan() === "ok" && fakeNetwork.scans === 1,
                "scan did not reach the fake NetworkManager owner")
            expect(network._begin("scan", "wifi") && network.scanning,
                "network scanning state was not exposed")
            network._finishModel("ok", "scan")

            expect(network.activate(openNetwork, "") === "ok" && openNetwork.connected,
                "open network join failed")
            expect(network.activate(openNetwork, "") === "ok" && !openNetwork.connected,
                "open network disconnect failed")
            expect(network.activate(savedNetwork, "") === "ok" && savedNetwork.connected,
                "saved network join failed")
            savedNetwork.connected = false
            expect(network.activate(personalNetwork, secret) === "ok"
                    && personalNetwork.connected,
                "personal secured network join failed")
            expect(network.lastCommandJson.indexOf(secret) === -1
                    && network.lastRequestSummary.indexOf(secret) === -1,
                "credential leaked into observable service state")
            personalNetwork.connected = false

            fakeNetwork.failNext = true
            expect(network.activate(personalNetwork, secret) === "error"
                    && network.lastError === "wrong password"
                    && !personalNetwork.connected,
                "join failure did not preserve owner truth")
            expect(network.openEditor(enterpriseNetwork) === "ok"
                    && events.indexOf("editor:enterprise") !== -1,
                "enterprise handoff failed")
            expect(network.openHiddenEditor() === "ok"
                    && events.indexOf("editor:hidden") !== -1,
                "hidden-network handoff failed")
            expect(network.openManager() === "ok"
                    && events.indexOf("editor:manage") !== -1,
                "network-manager handoff failed")

            expect(network.toggleVpn(otherVpn) === "read-only"
                    && fakeNetwork.vpnToggles === 0,
                "non-allowlisted VPN became writable")
            expect(network.toggleVpn(mobergVpn) === "ok"
                    && fakeNetwork.vpnToggles === 1,
                "MobergAnalytics quick toggle failed")
            expect(network.tailscale.status === "running"
                    && network.tailscale.ip === "100.64.0.8"
                    && network.tailscale.hostName === "fixture-host"
                    && network.tailscale.dnsName === "fixture-host.fixture.ts.net"
                    && network.tailscale.services.length === 2,
                "Tailscale metadata was not exposed")
            expect(network.copyTailscale("dns") === "ok"
                    && fakeNetwork.copiedTailscaleField === "dns",
                "Tailscale copy did not reach the network owner")
            expect(network.copyTailscale("service", "siren.fixture.ts.net") === "ok"
                    && fakeNetwork.copiedTailscaleField === "service"
                    && fakeNetwork.copiedTailscaleService === "siren.fixture.ts.net",
                "Tailscale service copy did not reach the network owner")

            expect(bluetooth.connectedDevices.length === 1
                    && bluetooth.pairedDevices.length === 2
                    && bluetooth.availableDevices.length === 1,
                "Bluetooth groups are incorrect")
            expect(bluetooth.batteryText(connectedDevice) === "63% battery",
                "Bluetooth battery state is incorrect")
            expect(bluetooth.scan() === "ok" && bluetooth.scanning,
                "Bluetooth scan did not reach BlueZ owner")
            expect(bluetooth.stopScan() === "ok" && !bluetooth.scanning,
                "Bluetooth scan stop did not reconcile")

            var eventStart = events.length
            expect(bluetooth.connectDevice(availableDevice) === "ok"
                    && availableDevice.connected && availableDevice.paired
                    && availableDevice.trusted,
                "Bluetooth connect did not pair, trust, and connect")
            expect(events[eventStart] === "connect:" + availableDevice.address
                    && events[eventStart + 1] === "audio:" + availableDevice.address,
                "audio default did not follow successful Bluetooth connect")
            expect(bluetooth.disconnectDevice(availableDevice) === "ok"
                    && !availableDevice.connected,
                "Bluetooth disconnect failed")
            expect(bluetooth._begin("forget", pairedDevice)
                    && bluetooth.statusFor(pairedDevice) === "forgetting",
                "Bluetooth Forget transition was not exposed")
            bluetooth._complete("fixture reset")
            expect(bluetooth.forgetDevice(pairedDevice) === "ok"
                    && !pairedDevice.paired && !pairedDevice.bonded,
                "Bluetooth Forget did not remove the bond")

            fakeBluetooth.failNext = true
            expect(bluetooth.connectDevice(failedDevice) === "error"
                    && bluetooth.failureFor(failedDevice) === "BlueZ rejected connection"
                    && !failedDevice.connected,
                "Bluetooth failure state did not preserve BlueZ truth")
            failedDevice.state = "connecting"
            expect(bluetooth.statusFor(failedDevice) === "connecting",
                "Bluetooth transition state was not exposed")

            console.log("CONNECTIVITY_FIXTURE_OK checks=" + checks)
            Qt.quit()
          } catch (error) {
              console.error("CONNECTIVITY_FIXTURE_FAIL " + error)
              Qt.quit()
          }
        }
    }
}
