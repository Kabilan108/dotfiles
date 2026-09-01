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

    Resources.ResourceService {
        id: resources
        context: root.fakeContext
        refreshTimer.running: false
    }

    Component.onCompleted: Qt.callLater(run)

    function verify(condition, message) {
        checks++
        if (!condition)
            throw new Error(message)
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
            verify(resources.refreshTimer.interval === 3000, "resource cadence")

            console.log("POWER_RESOURCES_FIXTURE_OK checks=" + checks)
            Qt.quit()
        } catch (error) {
            console.error("POWER_RESOURCES_FIXTURE_FAIL " + error)
            Qt.quit()
        }
    }
}
