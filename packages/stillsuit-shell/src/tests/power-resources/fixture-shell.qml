import QtQuick
import Quickshell
import "plugins/builtin/resources" as Resources
import "services" as Services
import "tests/FixtureTheme.js" as FixtureTheme

ShellRoot {
    id: root

    property int checks: 0
    property var fakeContext: QtObject {
        property var theme: FixtureTheme.create()
        property var panels: QtObject {
            function isOpen(pluginId) { return false }
        }
        property var actions: QtObject {
            function surfaceToggle(pluginId, payloadJson) { return "ok" }
        }
    }

    property var fakeBatteryDevice: QtObject {
        property bool isPresent: true
        property real percentage: 0.56
        property real timeToEmpty: 7200
        property real timeToFull: 0
    }

    property var fakeDetailDevice: QtObject {
        property real changeRate: NaN
    }

    property var fakeBatteryModel: QtObject {
        property int revision: 1
        property var device: root.fakeBatteryDevice
        property var detailDevice: root.fakeDetailDevice
        property string state: "discharging"
        property var details: ({
            healthPercent: "83.9026%",
            capacityWh: "46.1538 Wh",
            designCapacityWh: "55.0088 Wh",
            cycleCount: "181",
            powerDrawWatts: "12.47 W",
            chargeStartThreshold: "75%",
            chargeEndThreshold: "80%",
            chargeThresholdSupported: "yes"
        })
    }

    property var missingBatteryDevice: QtObject {
        property bool isPresent: true
        property real percentage: NaN
        property real timeToEmpty: NaN
        property real timeToFull: NaN
    }

    property var missingBatteryModel: QtObject {
        property int revision: 1
        property var device: root.missingBatteryDevice
        property string state: "unknown"
        property var details: ({})
    }

    property var fakePowerModel: QtObject {
        property int revision: 1
        property var profiles: ["power-saver", "balanced", "performance"]
        property string activeProfile: "balanced"
        property string actionResult: "ok"

        function setProfile(profile) {
            if (actionResult === "ok")
                activeProfile = profile
            return actionResult
        }
    }

    Services.BatteryService {
        id: battery
        context: root.fakeContext
        model: root.fakeBatteryModel
    }

    Services.BatteryService {
        id: missingBattery
        context: root.fakeContext
        model: root.missingBatteryModel
    }

    Services.PowerService {
        id: power
        context: root.fakeContext
        model: root.fakePowerModel
    }

    Services.PowerService {
        id: livePower
        context: root.fakeContext
    }

    Services.BatteryService {
        id: liveBattery
        context: root.fakeContext
    }

    property var fakeLiveBatteryDevice: QtObject {
        property bool healthSupported: true
        property real healthPercentage: 91.24
        property real energyCapacity: 50.04
    }

    Resources.ResourceService {
        id: resources
        context: root.fakeContext
        refreshTimer.running: false
    }

    Component.onCompleted: Qt.callLater(run)

    property int lifecyclePhase: 0
    Timer {
        id: lifecycleCheck
        interval: 200
        onTriggered: root.checkLifecycle()
    }

    function checkLifecycle() {
        try {
            if (lifecyclePhase === 0) {
                verify(!resources.localRefreshing && !resources.remoteRefreshing,
                    "commands that fail to start release both refresh flags")
                verify(!resources.localTimeout.running && !resources.remoteTimeout.running,
                    "failed command starts cancel request deadlines")
                verify(resources.localError !== "" && resources.remoteError !== "",
                    "failed command starts report an error")
                resources.localRefreshing = true
                resources.localError = ""
                resources.localCollector.command = ["sleep", "10"]
                resources.localTimeout.interval = 50
                resources.localTimeout.restart()
                resources.localCollector.running = true
                lifecyclePhase = 1
                lifecycleCheck.restart()
            } else {
                verify(!resources.localRefreshing && !resources.localCollector.running,
                    "timed-out request releases refresh state and process")
                verify(resources.localError.indexOf("timed out") !== -1,
                    "timeout preserves its reason after process exit")
                console.log("POWER_RESOURCES_FIXTURE_OK checks=" + checks)
                Qt.quit()
            }
        } catch (error) {
            console.error("POWER_RESOURCES_FIXTURE_FAIL " + error)
            Qt.quit()
        }
    }

    function verify(condition, message) {
        checks++
        if (!condition)
            throw new Error(message)
    }

    function findItem(item, name) {
        if (item.objectName === name)
            return item
        var children = item.children || []
        for (var index = 0; index < children.length; index++) {
            var result = findItem(children[index], name)
            if (result)
                return result
        }
        return null
    }

    function run() {
        try {
            var components = [
                "plugins/builtin/battery/Widget.qml",
                "plugins/builtin/resources/ResourceWidget.qml"
            ]
            for (var componentIndex = 0; componentIndex < components.length;
                    componentIndex++) {
                var component = Qt.createComponent(
                    components[componentIndex], Component.PreferSynchronous)
                verify(component.status === Component.Ready,
                    components[componentIndex] + ": " + component.errorString())
            }

            verify(battery.percentage === 56, "normalized percentage")
            verify(battery.state === "discharging", "discharging state")
            verify(battery.stateLabel === "On battery", "state label")
            verify(battery.timeText === "2h 00m", "time remaining")
            verify(battery.healthPercent === 83.9, "health normalization")
            verify(battery.capacityWh === 46.2, "capacity normalization")
            verify(battery.designCapacityWh === 55, "design capacity normalization")
            verify(battery.cycleCount === 181, "cycle normalization")
            verify(battery.powerDrawWatts === 12.5, "power draw normalization")
            verify(battery.chargeStartThreshold === 75, "start threshold")
            verify(battery.chargeEndThreshold === 80, "end threshold")
            verify(battery.chargeThresholdSupported, "threshold support")

            var batteryWidgetComponent = Qt.createComponent(
                "plugins/builtin/battery/Widget.qml", Component.PreferSynchronous)
            var batteryWidget = batteryWidgetComponent.createObject(root, {
                context: fakeContext,
                service: battery,
                outputId: "fixture-output"
            })
            verify(batteryWidget !== null, "battery widget construction")
            verify(batteryWidget.displayIconName === "battery-level-4",
                "mid-level discharge icon")
            fakeBatteryModel.state = "charging"
            verify(batteryWidget.displayIconName === "battery-charging",
                "charging icon")
            fakeBatteryModel.state = "discharging"
            fakeBatteryDevice.percentage = 0.05
            verify(batteryWidget.displayIconName === "battery-alert",
                "critical battery icon")
            fakeBatteryDevice.percentage = 0.98
            fakeBatteryModel.state = "fully-charged"
            verify(batteryWidget.displayIconName === "battery-level-full",
                "full battery icon")
            fakeBatteryDevice.percentage = 0.56
            fakeBatteryModel.state = "discharging"
            batteryWidget.destroy()

            var parsed = battery._normalizeDetails(battery._parseDetails(
                "Device: /org/freedesktop/UPower/devices/line_power_AC\n"
                + "  online: yes\n\n"
                + "Device: /org/freedesktop/UPower/devices/battery_BAT1\n"
                + "  battery\n"
                + "    energy-full: 44.04 Wh\n"
                + "    energy-full-design: 55.05 Wh\n"
                + "    energy-rate: 9.96 W\n"
                + "    charge-cycles: N/A\n"
                + "    capacity: 80.01%\n"
                + "    charge-start-threshold: 0.75\n"
                + "    charge-end-threshold: 82%\n"
                + "    charge-threshold-supported: yes\n"))
            verify(parsed.healthPercent === 80, "dump health parsing")
            verify(parsed.capacityWh === 44, "dump capacity parsing")
            verify(parsed.designCapacityWh === 55.1, "dump design parsing")
            verify(parsed.powerDrawWatts === 10, "dump draw parsing")
            verify(parsed.cycleCount === null, "N/A cycle parsing")
            verify(parsed.chargeStartThreshold === 75, "ratio threshold parsing")
            verify(parsed.chargeEndThreshold === 82, "percent threshold parsing")

            fakeBatteryModel.state = "pending-charge"
            verify(battery.pending, "pending charge state")
            verify(battery.stateLabel === "Waiting to charge", "pending charge label")
            verify(battery.timeText === "", "pending charge time suppressed")
            fakeBatteryModel.state = "pending-discharge"
            verify(battery.pending, "pending discharge state")
            verify(battery.stateLabel === "Waiting to discharge",
                "pending discharge label")

            verify(missingBattery.percentage === 0, "missing percentage")
            verify(missingBattery.timeText === "", "missing time")
            verify(missingBattery.healthPercent === null, "missing health")
            verify(missingBattery.cycleCount === null, "missing cycles")
            verify(missingBattery.powerDrawWatts === null, "missing draw")
            verify(!missingBattery.chargeThresholdSupported,
                "missing thresholds")

            verify(power.activeProfile === "balanced", "initial daemon profile")
            fakePowerModel.activeProfile = "performance"
            fakePowerModel.revision++
            verify(power.activeProfile === "performance", "external profile change")

            fakePowerModel.actionResult = "ok"
            verify(power.setProfile("power-saver") === "ok", "profile action accepted")
            verify(power.activeProfile === "power-saver", "profile success reconciled")
            verify(!power.busy && power.pendingProfile === "", "success clears busy")

            fakePowerModel.actionResult = "error"
            verify(power.setProfile("balanced") === "error", "profile failure returned")
            verify(power.activeProfile === "power-saver", "profile failure rollback")
            verify(power.displayProfile === "power-saver", "rollback is visible")
            verify(!power.busy && power.errorMessage !== "", "failure status")

            fakePowerModel.actionResult = "pending"
            verify(power.setProfile("performance") === "pending", "pending action")
            verify(power.busy && power.displayProfile === "performance",
                "pending profile visible")
            fakePowerModel.activeProfile = "performance"
            fakePowerModel.revision++
            verify(!power.busy && power.activeProfile === "performance",
                "pending action reconciled")

            var merged = battery._normalizeDetails(battery._mergeLiveDetails(
                fakeLiveBatteryDevice, {
                    healthPercent: "80%",
                    capacityWh: "44 Wh",
                    designCapacityWh: "55 Wh",
                    cycleCount: "12"
                }))
            verify(merged.healthPercent === 91.2, "live health overrides dump")
            verify(merged.capacityWh === 50, "live capacity overrides dump")
            verify(merged.designCapacityWh === 55 && merged.cycleCount === 12,
                "dump-only fields retained")
            fakeLiveBatteryDevice.healthSupported = false
            fakeLiveBatteryDevice.energyCapacity = 0
            merged = battery._normalizeDetails(battery._mergeLiveDetails(
                fakeLiveBatteryDevice, { healthPercent: "80%", capacityWh: "44 Wh" }))
            verify(merged.healthPercent === 80 && merged.capacityWh === 44,
                "unsupported live values fall back to dump")
            verify(!liveBattery.detailRefreshDelay.repeat,
                "battery details are not polled")
            if (liveBattery.laptopBattery === null) {
                liveBattery.refreshDetails()
                verify(!liveBattery.detailProcess.running,
                    "no battery runs no detail helper")
            }

            livePower._finishProbe(1, "Failed to communicate with power-profiles-daemon")
            verify(!livePower.available && livePower.profiles.length === 0
                    && livePower.displayProfile === "",
                "absent daemon reports unavailable without a profile")
            verify(livePower.setProfile("balanced") === "unavailable",
                "absent daemon rejects profile changes")
            livePower._finishProbe(0, "  balanced:\n"
                + "    CpuDriver:\tamd_pstate\n"
                + "    PlatformDriver:\tplaceholder\n\n"
                + "* power-saver:\n"
                + "    CpuDriver:\tamd_pstate\n"
                + "    PlatformDriver:\tplaceholder\n")
            verify(livePower.available && livePower.activeProfile === "power-saver"
                    && JSON.stringify(livePower.profiles)
                        === '["power-saver","balanced"]',
                "daemon probe without performance profile")
            var withPerformance = livePower._parseProbe("* performance:\n"
                + "    CpuDriver:\tintel_pstate\n"
                + "    Degraded:   no\n\n"
                + "  balanced:\n    CpuDriver:\tintel_pstate\n\n"
                + "  power-saver:\n    CpuDriver:\tintel_pstate\n")
            verify(withPerformance.activeProfile === "performance"
                    && JSON.stringify(withPerformance.profiles)
                        === '["power-saver","balanced","performance"]',
                "daemon probe orders profiles")
            verify(livePower._parseProbe("garbage") === null,
                "malformed probe output is unavailable")
            livePower._finishProbe(1, "")
            verify(!livePower.available, "daemon loss reports unavailable")

            resources.updateCpu("cpu 100 0 100 800 0 0 0 0\n")
            resources.updateCpu("cpu 150 0 150 900 0 0 0 0\n")
            verify(resources.cpuPercent === 50, "CPU delta")
            resources.updateMemory("MemTotal: 1000 kB\nMemAvailable: 250 kB\n")
            verify(resources.memoryPercent === 75, "memory change")
            resources.updateCpu("cpu invalid data\n")
            resources.updateMemory("MemTotal: 1000 kB\n")
            verify(resources.cpuPercent === 50, "malformed CPU preserves last good")
            verify(resources.memoryPercent === 75,
                "missing memory preserves last good")
            resources.previousTotal = 0
            resources.updateCpu("cpu 100 0 100 800 0 0 0 0 50 0\n")
            resources.updateCpu("cpu 150 0 150 900 0 0 0 0 100 0\n")
            verify(resources.cpuPercent === 50, "guest CPU time is not counted twice")
            verify(resources.refreshTimer.interval === 3000, "resource cadence")
            verify(resources.usageBand(59) === "normal", "normal usage band")
            verify(resources.usageBand(60) === "elevated", "elevated usage band")
            verify(resources.usageBand(75) === "high", "high usage band")
            verify(resources.usageBand(90) === "critical", "critical usage band")
            verify(resources.usageBand("invalid") === "", "invalid usage band")

            var sample = {
                schemaVersion: 1, cpuPercent: 82, memoryPercent: 45,
                load: [2, 1, 0.5], pressure: {cpu: 1.2, memory: 0, io: 0}, gpus: []
            }
            resources.remoteError = "Previous request failed"
            verify(resources.applySnapshot(JSON.stringify(sample), true), "PC snapshot accepted")
            var goodSnapshot = resources.remoteSnapshot
            var goodTime = resources.remoteUpdatedAt
            verify(resources.remoteError === "", "successful snapshot clears old failure")
            verify(!resources.applySnapshot('{"schemaVersion":1}', true), "partial PC snapshot rejected")
            sample.cpuPercent = null
            verify(!resources.applySnapshot(JSON.stringify(sample), true), "missing CPU is not zero")
            sample.cpuPercent = 101
            verify(!resources.applySnapshot(JSON.stringify(sample), true), "invalid percentage rejected")
            verify(resources.remoteSnapshot === goodSnapshot && resources.remoteUpdatedAt === goodTime,
                "failed samples preserve last good data and its age")
            resources.remoteUpdatedAt = resources.now - 61000
            verify(resources.remoteStale, "cached PC sample becomes stale")
            verify(resources.headline(true) === "CPU 82% · MEM 45%", "PC tooltip omits sample age")
            resources.remoteError = "Connection failed"
            verify(resources.headline(true).indexOf("unavailable") !== -1,
                "failed connection does not imply a current sample")
            resources.fleet = { self: "fixture", machines: {
                fixture: { canAccess: ["desktop"] }, desktop: { role: "agent-worker" }
            } }
            verify(resources.remoteName === "desktop", "PC target comes from allowed fleet worker")
            resources.fleet = { self: "desktop", machines: {desktop: {canAccess: []}} }
            verify(!resources.remoteAvailable, "desktop never SSHes back to laptop")
            // Mark requests busy so this ownership check has no external processes.
            resources.localRefreshing = true
            resources.setPanelOpen("first", true)
            resources.setPanelOpen("second", true)
            verify(resources.detailTimer.running, "open panel enables detailed local sampling")
            resources.setPanelOpen("first", false)
            verify(resources.detailTimer.running && resources.panelOutputs.length === 1,
                "closing one output preserves the other panel's sampling")
            resources.setPanelOpen("second", false)
            verify(!resources.detailTimer.running, "closing final panel stops detailed sampling")
            resources.localRefreshing = false
            resources.setHovered("first", true)
            resources.setHovered("second", true)
            resources.setHovered("first", false)
            verify(resources.hoveredOutputId === "second" && resources.hoverDelay.running,
                "leaving one output does not dismiss another output's pending tooltip")
            resources.setHovered("second", false)
            verify(!resources.hoverDelay.running && resources.tooltipOutputId === "",
                "hover exit cancels tooltip delay and visibility")
            // Restore the deterministic bar values after refreshDetails read /proc.
            resources.cpuPercent = 50
            resources.memoryPercent = 75

            var resourceWidgetComponent = Qt.createComponent(
                "plugins/builtin/resources/ResourceWidget.qml",
                Component.PreferSynchronous)
            var resourceWidget = resourceWidgetComponent.createObject(root, {
                context: fakeContext,
                service: resources,
                outputId: "fixture-output"
            })
            verify(resourceWidget !== null, "resource widget construction")
            verify(resourceWidget.cpuLabel === "CPU:", "CPU label contract")
            verify(resourceWidget.memoryLabel === "MEM:", "memory label contract")
            verify(resourceWidget.accessibleName === "CPU 50%, memory 75%",
                "resource widget accessible name")
            verify(String(resourceWidget.cpuColor).toLowerCase() === "#a6e3a1",
                "normal CPU color")
            verify(String(resourceWidget.memoryColor).toLowerCase() === "#fab387",
                "high memory color")
            resourceWidget.destroy()

            var cardComponent = Qt.createComponent("plugins/builtin/resources/HostCard.qml",
                Component.PreferSynchronous)
            verify(cardComponent.status === Component.Ready, "host view compiles: " + cardComponent.errorString())
            var cardProperties = {
                theme: fakeContext.theme, service: resources, hostName: "fixture",
                remote: false, refreshing: false, errorMessage: "", updatedAt: 0,
                snapshot: { cpuPercent: 25, memoryPercent: 50,
                    memoryUsedBytes: 16 * 1073741824, memoryTotalBytes: 32 * 1073741824,
                    cpuTemperature: 50, pressure: {cpu: 0, memory: 1.2, io: 0},
                    gpus: [{name: "NVIDIA GeForce RTX 3090", percent: 70,
                        usedBytes: 6 * 1073741824, totalBytes: 24 * 1073741824, temperature: 60}] }
            }
            var laptopCard = cardComponent.createObject(root, cardProperties)
            verify(laptopCard !== null && laptopCard.gpus.length === 0,
                "laptop hides GPU telemetry even when the collector supplies it")
            verify(findItem(laptopCard, "host-gpu-compute") === null,
                "laptop does not construct GPU meters")
            laptopCard.destroy()
            cardProperties.remote = true
            var pcCard = cardComponent.createObject(root, cardProperties)
            verify(pcCard !== null, "PC host view construction")
            var cpuMeter = findItem(pcCard, "host-cpu")
            var memoryMeter = findItem(pcCard, "host-memory")
            var computeMeter = findItem(pcCard, "host-gpu-compute")
            var vramMeter = findItem(pcCard, "host-gpu-vram")
            verify(cpuMeter && memoryMeter && computeMeter && vramMeter,
                "PC constructs CPU, memory, compute and VRAM meters")
            verify(computeMeter.percent === 70 && vramMeter.percent === 25,
                "compute uses utilization and VRAM uses occupied capacity")
            verify(cpuMeter.detail === "50°C" && memoryMeter.detail === "16.0 / 32.0 GiB",
                "temperature and memory details are attached to their meters")
            verify(pcCard.vramPercent({usedBytes: null, totalBytes: 24}) === null
                    && pcCard.vramPercent({usedBytes: 6, totalBytes: 0}) === null,
                "missing VRAM counters are unavailable rather than zero")
            verify(pcCard.pressure("memory") === "1.2%", "pressure keeps useful precision")
            verify(pcCard.pressureRole("cpu") === "muted" && pcCard.pressureRole("memory") === "secondary",
                "pressure below one percent recedes and nonzero pressure is legible")
            pcCard.snapshot = Object.assign({}, cardProperties.snapshot, {pressure: {cpu: 10, memory: null, io: 0}})
            verify(pcCard.pressureRole("cpu") === "warning" && pcCard.pressureRole("memory") === "muted",
                "high pressure warns and missing pressure stays muted")
            var meters = [cpuMeter, memoryMeter, computeMeter, vramMeter]
            verify(pcCard.labelWidth > 0 && pcCard.detailWidth > 0 && pcCard.percentWidth > 0,
                "meter columns are measured")
            verify(meters.every(function(meter) {
                    return meter.labelWidth === pcCard.labelWidth && meter.detailWidth === pcCard.detailWidth
                        && meter.percentWidth === pcCard.percentWidth
                }), "every meter row shares the host's column widths so the bars align")
            pcCard.destroy()

            resources.localRefreshing = true
            resources.remoteRefreshing = true
            resources.localError = ""
            resources.remoteError = ""
            resources.localCollector.command = ["/nonexistent-stillsuit-resource-test"]
            resources.remoteCollector.command = ["/nonexistent-stillsuit-resource-test"]
            resources.localTimeout.restart()
            resources.remoteTimeout.restart()
            resources.localCollector.running = true
            resources.remoteCollector.running = true
            lifecycleCheck.restart()
        } catch (error) {
            console.error("POWER_RESOURCES_FIXTURE_FAIL " + error)
            Qt.quit()
        }
    }
}
