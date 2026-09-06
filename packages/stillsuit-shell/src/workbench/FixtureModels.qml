// Builds the `model` objects that Stillsuit services accept in place of live
// hardware and helpers, from one fixture document. Services keep their own
// derived state; only the inputs are synthetic.
import QtQuick

QtObject {
    id: root

    property var fixture: ({})
    property int revision: 0
    readonly property var compositorSnapshot: fixture.compositor || ({})
    readonly property var services: fixture.services || ({})

    signal actionRecorded(string pluginId, string action, var detail)

    property Component batteryComponent: Component {
        QtObject {
            property int revision: 0
            property string state: "unknown"
            property var device: null
            property var details: ({})
        }
    }

    property Component powerComponent: Component {
        QtObject {
            property int revision: 0
            property var profiles: []
            property string activeProfile: ""
            function setProfile(profile) {
                activeProfile = String(profile)
                revision += 1
                root.actionRecorded("stillsuit.power", "setProfile", profile)
                return "ok"
            }
        }
    }

    property Component networkComponent: Component {
        QtObject {
            property int revision: 0
            property bool wifiEnabled: true
            property bool wiredConnected: false
            property string wiredName: ""
            property var networks: []
            property var wiredConnections: []
            property var vpns: []
            property var tailscale: ({})
            function scan() { root.actionRecorded("stillsuit.network", "scan", ""); return "ok" }
            function refresh() { root.actionRecorded("stillsuit.network", "refresh", ""); return "ok" }
            function setWifiEnabled(value) {
                wifiEnabled = Boolean(value); revision += 1
                root.actionRecorded("stillsuit.network", "setWifiEnabled", value); return "ok"
            }
            function join(network, password) {
                for (var i = 0; i < networks.length; i++) networks[i].connected = networks[i] === network
                revision += 1
                root.actionRecorded("stillsuit.network", "join", network ? network.name : ""); return "ok"
            }
            function disconnect(network) {
                if (network) network.connected = false
                revision += 1
                root.actionRecorded("stillsuit.network", "disconnect", network ? network.name : ""); return "ok"
            }
            function activate(target) { root.actionRecorded("stillsuit.network", "activate", target); return "ok" }
            function toggleVpn(vpn) {
                if (vpn) vpn.active = !vpn.active
                revision += 1
                root.actionRecorded("stillsuit.network", "toggleVpn", vpn ? vpn.name : ""); return "ok"
            }
            function openEditor(mode, network) { root.actionRecorded("stillsuit.network", "openEditor", mode); return "ok" }
            function copyTailscale(field, serviceName) { root.actionRecorded("stillsuit.network", "copyTailscale", field); return "ok" }
        }
    }

    property Component bluetoothDeviceComponent: Component {
        QtObject {
            property string address: ""
            property string name: ""
            property bool connected: false
            property bool paired: false
            property bool bonded: false
            property bool trusted: false
            property bool batteryAvailable: false
            property real battery: 0
            property string state: "disconnected"
        }
    }

    property Component bluetoothComponent: Component {
        QtObject {
            property int revision: 0
            property bool enabled: true
            property bool scanning: false
            property var devices: []
            function setEnabled(value) { enabled = Boolean(value); revision += 1; root.actionRecorded("stillsuit.bluetooth", "setEnabled", value); return "ok" }
            function scan() { scanning = true; revision += 1; root.actionRecorded("stillsuit.bluetooth", "scan", ""); return "ok" }
            function stopScan() { scanning = false; revision += 1; root.actionRecorded("stillsuit.bluetooth", "stopScan", ""); return "ok" }
            function connectDevice(device) { if (device) { device.connected = true; device.state = "connected" } revision += 1; root.actionRecorded("stillsuit.bluetooth", "connect", device ? device.name : ""); return "ok" }
            function connect(device) { return connectDevice(device) }
            function disconnectDevice(device) { if (device) { device.connected = false; device.state = "disconnected" } revision += 1; root.actionRecorded("stillsuit.bluetooth", "disconnect", device ? device.name : ""); return "ok" }
            function disconnect(device) { return disconnectDevice(device) }
            function forgetDevice(device) {
                devices = devices.filter(function(entry) { return entry !== device }); revision += 1
                root.actionRecorded("stillsuit.bluetooth", "forget", device ? device.name : ""); return "ok"
            }
            function forget(device) { return forgetDevice(device) }
            function makeDefaultAudio(device) { root.actionRecorded("stillsuit.bluetooth", "makeDefaultAudio", device ? device.name : ""); return "ok" }
        }
    }

    property Component playerComponent: Component {
        QtObject {
            property string dbusName: ""
            property string identity: ""
            property string trackTitle: ""
            property string trackArtist: ""
            property string trackAlbum: ""
            property string trackArtUrl: ""
            property bool isPlaying: false
            property real position: 0
            property real length: 0
            property bool lengthSupported: false
            property bool canSeek: false
            property bool canGoPrevious: false
            property bool canTogglePlaying: false
            property bool canGoNext: false
            property bool shuffleSupported: false
            property bool shuffle: false
            property bool loopSupported: false
            property string loopState: "none"
            function togglePlaying() { isPlaying = !isPlaying; root.actionRecorded("stillsuit.audio", "togglePlaying", identity) }
            function next() { root.actionRecorded("stillsuit.audio", "next", identity) }
            function previous() { root.actionRecorded("stillsuit.audio", "previous", identity) }
            function seek(offset) { position = Math.max(0, position + offset); root.actionRecorded("stillsuit.audio", "seek", offset) }
        }
    }

    property Component mediaComponent: Component {
        QtObject {
            property var players: []
            property bool failed: false
            property string errorMessage: ""
            function togglePlaying(player) { if (player) player.togglePlaying() }
            function next(player) { if (player) player.next() }
            function previous(player) { if (player) player.previous() }
            function seekTo(player, target) { if (player) player.position = target; root.actionRecorded("stillsuit.audio", "seekTo", target) }
            function setShuffle(player, enabled) { if (player) player.shuffle = enabled; root.actionRecorded("stillsuit.audio", "setShuffle", enabled) }
            function setRepeatMode(player, mode) { if (player) player.loopState = mode; root.actionRecorded("stillsuit.audio", "setRepeatMode", mode) }
        }
    }

    property Component audioComponent: Component {
        QtObject {
            property int revision: 0
            property real volume: 0.5
            property bool muted: false
            property real inputVolume: 0.5
            property bool inputMuted: false
            property var sink: ({})
            property var source: ({})
            property var outputs: []
            property var media: null
            function setVolume(value) { volume = value; revision += 1; root.actionRecorded("stillsuit.audio", "setVolume", value) }
            function toggleMuted() { muted = !muted; revision += 1; root.actionRecorded("stillsuit.audio", "toggleMuted", muted) }
            function setInputVolume(value) { inputVolume = value; revision += 1; root.actionRecorded("stillsuit.audio", "setInputVolume", value) }
            function toggleInputMuted() { inputMuted = !inputMuted; revision += 1; root.actionRecorded("stillsuit.audio", "toggleInputMuted", inputMuted) }
            function selectOutput(name) {
                for (var i = 0; i < outputs.length; i++) outputs[i].active = outputs[i].name === name
                revision += 1
                root.actionRecorded("stillsuit.audio", "selectOutput", name); return "ok"
            }
        }
    }

    property Component agentUsageComponent: Component {
        QtObject {
            property int revision: 0
            property var accounts: []
            property var summary: ({})
            property string updatedAt: ""
            function refresh(force) { root.actionRecorded("stillsuit.agent-usage", "refresh", Boolean(force)) }
        }
    }

    property var built: ({})

    function rebuild() {
        _destroyAll()
        var next = {}
        var s = services
        if (s["stillsuit.battery"]) {
            // Fixtures write human percentages; the service expects UPower's 0-1 scale.
            var battery = _plain(s["stillsuit.battery"])
            if (battery.device && battery.device.percentage > 1)
                battery.device.percentage = battery.device.percentage / 100
            next["stillsuit.battery"] = batteryComponent.createObject(root, battery)
        }
        if (s["stillsuit.power"])
            next["stillsuit.power"] = powerComponent.createObject(root, _plain(s["stillsuit.power"]))
        if (s["stillsuit.network"])
            next["stillsuit.network"] = networkComponent.createObject(root, _plain(s["stillsuit.network"]))
        if (s["stillsuit.bluetooth"]) {
            var bt = _plain(s["stillsuit.bluetooth"])
            var devices = []
            for (var d = 0; d < (bt.devices || []).length; d++)
                devices.push(bluetoothDeviceComponent.createObject(root, bt.devices[d]))
            bt.devices = devices
            next["stillsuit.bluetooth"] = bluetoothComponent.createObject(root, bt)
        }
        if (s["stillsuit.audio"]) {
            var audio = _plain(s["stillsuit.audio"])
            var mediaSpec = audio.media || { players: [] }
            delete audio.media
            var players = []
            for (var p = 0; p < (mediaSpec.players || []).length; p++)
                players.push(playerComponent.createObject(root, mediaSpec.players[p]))
            mediaSpec.players = players
            audio.media = mediaComponent.createObject(root, mediaSpec)
            next["stillsuit.audio"] = audioComponent.createObject(root, audio)
        }
        if (s["stillsuit.agent-usage"])
            next["stillsuit.agent-usage"] = agentUsageComponent.createObject(root, _plain(s["stillsuit.agent-usage"]))
        built = next
        revision += 1
    }

    function modelFor(pluginId) {
        return built[String(pluginId)] || null
    }

    function _plain(value) {
        return JSON.parse(JSON.stringify(value))
    }

    function _destroyAll() {
        for (var key in built) {
            var object = built[key]
            if (object && typeof object.destroy === "function") object.destroy()
        }
        built = {}
    }
}
