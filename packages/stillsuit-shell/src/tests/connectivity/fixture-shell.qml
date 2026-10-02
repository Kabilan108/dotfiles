import QtQuick
import Quickshell
import Quickshell.Networking
import "services" as Services
import "tests/FixtureTheme.js" as FixtureTheme
import "ui" as Ui

ShellRoot {
    id: root

    property int checks: 0
    property string secret: "fixture-personal-secret"
    property var events: []
    property int panelCloses: 0
    property var fakeContext: QtObject {
        property var actions: QtObject {
            function surfaceClose(id) {
                if (id === "stillsuit.network") root.panelCloses++
            }
        }
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

    property var viewContext: QtObject {
        property var theme: FixtureTheme.create()
        property var panels: QtObject {
            property string selectedId: ""
            property string selectedOutputId: ""
        }
        property var actions: QtObject {
            function surfaceToggle(id, payload) { return "ok" }
            function surfaceClose(id) { return "ok" }
        }
    }
    property Component networkWidget: Qt.createComponent("plugins/builtin/network/Widget.qml")
    property Component networkPanel: Qt.createComponent("plugins/builtin/network/Panel.qml")

    property var liveWired: QtObject {
        property int type: DeviceType.Wired
        property string name: "enp4s0"
        property bool connected: true
        property bool hasLink: true
        property int state: ConnectionState.Connected
    }
    property var liveWiredDown: QtObject {
        property int type: DeviceType.Wired
        property string name: "enp5s0"
        property bool connected: false
        property bool hasLink: false
        property int state: ConnectionState.Disconnected
    }
    Services.NetworkService {
        id: staleProbe
        context: root.fakeContext
        model: root.fakeNetwork
    }

    property var liveWifiKnownOnly: QtObject {
        property int type: DeviceType.Wifi
        property string name: "wlan0"
        property bool connected: true
        property bool scannerEnabled: false
        property int state: ConnectionState.Connected
        property var networks: QtObject {
            property var values: [
                { name: "Home", known: true, connected: true, signalStrength: 0.81,
                    security: WifiSecurityType.Wpa2Psk }
            ]
        }
    }
    property var liveWifiOld: QtObject {
        property int type: DeviceType.Wifi
        property string name: "wlan0"
        property bool connected: true
        property int state: ConnectionState.Connected
        property var networks: QtObject {
            property var values: [
                { name: "Old", known: true, connected: true, signalStrength: 0.7,
                    security: WifiSecurityType.Wpa2Psk }
            ]
        }
    }
    property var scanSnapshot: ({
        networks: [
            { id: "home-uuid", name: "Home", uuid: "home-uuid", known: true,
                connected: false, kind: "personal", signal: 20, signalStrength: 0.2 },
            { id: "Library", name: "Library", uuid: "", known: false,
                connected: true, kind: "open", security: "--", signal: 55,
                signalStrength: 0.55 }
        ]
    })
    property var liveWifi: QtObject {
        property int type: DeviceType.Wifi
        property string name: "wlan0"
        property bool connected: true
        property bool scannerEnabled: false
        property int state: ConnectionState.Connected
        property var networks: QtObject {
            property var values: [
                { name: "Home", known: true, connected: true, signalStrength: 0.81,
                    security: WifiSecurityType.Wpa2Psk },
                { name: "Cafe", known: false, connected: false, signalStrength: 0.4,
                    security: WifiSecurityType.Open },
                { name: "Corp", known: false, connected: false, signalStrength: 0.9,
                    security: WifiSecurityType.Wpa2Eap },
                { name: "Cafe", known: false, connected: false, signalStrength: 0.6,
                    security: WifiSecurityType.Open },
                { name: "", known: false, connected: false, signalStrength: 0.99,
                    security: WifiSecurityType.Sae }
            ]
        }
    }
    property var helperSnapshot: ({
        wiredConnections: [{ device: "enp4s0", name: "Wired connection 1",
            addresses: ["192.0.2.10/24"], carrier: "on" }],
        networks: [{ name: "Home", uuid: "home-uuid", profileName: "Home profile" }],
        vpns: [root.mobergVpn],
        tailscale: ({ available: true, status: "running", ip: "100.64.0.8",
            hostName: "fixture-host", dnsName: "fixture-host.fixture.ts.net",
            services: [] })
    })

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
            expect(!network.networkingBackend && !network.networkingActive
                    && !network.scannerWanted
                    && !network.refreshTimer.running && !network.sanityTimer.running,
                "an injected model must not reach Quickshell.Networking or poll")

            var live = network.liveSnapshot([liveWired, liveWiredDown, liveWifi],
                true, helperSnapshot)
            expect(live.wifiEnabled && live.wifiConnected && live.wiredConnected
                    && live.wiredName === "Wired connection 1"
                    && live.wiredConnections.length === 1
                    && live.wiredConnections[0].device === "enp4s0"
                    && live.wiredConnections[0].addresses[0] === "192.0.2.10/24",
                "live wired devices did not map onto the snapshot shape")
            expect(live.networks.map(function(row) { return row.name }).join(",")
                    === "Home,Corp,Cafe",
                "live Wi-Fi networks were not deduplicated and ordered")
            expect(live.networks[0].connected && live.networks[0].known
                    && live.networks[0].uuid === "home-uuid"
                    && live.networks[0].id === "home-uuid"
                    && live.networks[0].kind === "personal"
                    && live.networks[0].signal === 81
                    && network.signalPercentage(live.networks[0]) === 81,
                "saved live network lost its helper profile or signal")
            expect(live.networks[1].kind === "enterprise"
                    && live.networks[2].kind === "open"
                    && live.networks[2].signal === 60
                    && live.networks[2].uuid === "" && live.networks[2].id === "Cafe",
                "live network security kinds are incorrect")
            expect(live.vpns.length === 1 && live.tailscale.ip === "100.64.0.8",
                "helper VPN and Tailscale data were not merged into live state")
            var scanned = network.liveSnapshot([liveWifiKnownOnly], true, scanSnapshot)
            expect(scanned.networks.map(function(row) { return row.name }).join(",")
                    === "Home,Library",
                "an unsaved SSID from the helper scan is missing from the live list")
            expect(scanned.networks[0].signal === 81 && scanned.networks[0].connected
                    && scanned.networks[1].kind === "open" && !scanned.networks[1].known
                    && !scanned.networks[1].connected,
                "live rows must win over helper rows, and helper-only rows are never connected")
            expect(network.liveSnapshot([liveWifiKnownOnly], false, scanSnapshot)
                    .networks.length === 0,
                "helper rows leaked into the list with the Wi-Fi radio off")

            network.applyScanner([liveWired, liveWifiKnownOnly], true)
            expect(liveWifiKnownOnly.scannerEnabled,
                "the Wi-Fi scanner was not enabled for the open panel")
            network.applyScanner([liveWired, liveWifiKnownOnly], false)
            expect(!liveWifiKnownOnly.scannerEnabled, "the Wi-Fi scanner was left running")

            var oldSsid = network.liveSnapshot([liveWired, liveWifiOld], true, null)
            expect(oldSsid.wifiSsid === "Old"
                    && oldSsid.wiredDevices.join(",") === "enp4s0",
                "live connected SSID or wired devices were not exposed")
            var newSummary = { wiredActive: true, wiredDevices: ["enp4s0"],
                wifiActive: true, wifiSsid: "New" }
            expect(!network.summaryMatches(newSummary, oldSsid)
                    && network.summaryMatches({ wiredActive: true,
                        wiredDevices: ["enp4s0"], wifiActive: true, wifiSsid: "Old" }, oldSsid)
                    && !network.summaryMatches({ wiredActive: true,
                        wiredDevices: ["enp5s0"], wifiActive: true, wifiSsid: "Old" }, oldSsid),
                "summary comparison ignored the SSID or wired device")
            expect(!staleProbe.checkBackend(newSummary, oldSsid)
                    && staleProbe.staleStrikes === 1 && !staleProbe.networkingStale,
                "one SSID disagreement must only record a strike")
            expect(staleProbe.checkBackend(newSummary, oldSsid)
                    && staleProbe.networkingStale && staleProbe.staleStrikes === 0,
                "a second SSID disagreement must fall back to helper polling")

            var bare = network.liveSnapshot([liveWired, liveWifi], false, null)
            expect(bare.wiredName === "enp4s0" && bare.wiredConnections[0].carrier === "on"
                    && bare.wiredConnections[0].addresses.length === 0
                    && bare.networks.length === 0 && bare.wifiConnected
                    && !bare.tailscale.available && bare.vpns.length === 0,
                "live state without a helper snapshot is incorrect")
            expect(network.summaryMatches({ wiredActive: true, wifiActive: true }, live)
                    && !network.summaryMatches({ wiredActive: true, wifiActive: false }, live)
                    && !network.summaryMatches({ wiredActive: false, wifiActive: true }, live),
                "stale-backend summary comparison is incorrect")

            var widget = networkWidget.createObject(root, {
                context: viewContext, service: network, outputId: "fixture-output"
            })
            expect(widget && !widget.busy, "network widget failed to load idle")
            expect(network._begin("scan", "wifi") && !widget.busy,
                "a Wi-Fi scan must not mark the bar chip busy")
            network._finishModel("ok", "scan")
            expect(network._begin("join", "saved-uuid") && widget.busy,
                "a join must mark the bar chip busy")
            network._finishModel("ok", "join")
            expect(network._begin("wifi-enabled", "wifi") && widget.busy,
                "a Wi-Fi toggle must mark the bar chip busy")
            network._finishModel("ok", "wifi-enabled")
            expect(!widget.busy, "network widget stayed busy after the operation")
            widget.destroy()

            var panel = networkPanel.createObject(root, {
                context: viewContext, service: network, screen: null,
                outputId: "fixture-output"
            })
            expect(panel && panel.connectedRows.length === 0
                    && panel.availableRows.length === 0 && panel.savedRows.length === 0
                    && panel.allowlistedVpns.length === 0,
                "a closed network panel must not derive network rows")
            panel.open("{}")
            expect(panel.availableRows.length === 2 && panel.savedRows.length === 2
                    && panel.allowlistedVpns.length === 1
                    && panel.activeReadOnlyVpns.length === 1,
                "an opened network panel did not derive its rows")
            panel.close()
            expect(panel.availableRows.length === 0 && panel.allowlistedVpns.length === 0,
                "a closed network panel kept deriving rows")
            panel.destroy()
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
            expect(panelCloses === 3, "successful editor handoffs must close the network panel")
            network._handleResponse(JSON.stringify({operation: "open-editor", ok: false, error: "launch failed"}))
            expect(panelCloses === 3, "failed editor launch must retain the panel")
            network._handleResponse(JSON.stringify({operation: "open-editor", ok: true, handoff: true}))
            expect(panelCloses === 4, "helper handoff closes only after success")

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
            expect(bluetooth.operation === "idle",
                "Bluetooth discovery must not mark the bar chip busy")
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
