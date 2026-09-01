// SPDX-License-Identifier: MIT

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "ui" as Ui

ShellRoot {
    id: fixture

    property int checks: 0
    property real sliderOwnerValue: 50
    property var theme: ({
        schemaVersion: 2,
        semantic: {
            surface: {
                panel: "#101010",
                pressed: "#202020"
            },
            content: {
                primary: "#f0f0f0",
                secondary: "#d0d0d0",
                muted: "#a0a0a0",
                disabled: "#707070"
            },
            outline: {
                subtle: "#303030",
                default: "#404040",
                focus: "#5050ff"
            },
            accent: {
                primary: "#6060ff",
                onAccent: "#080808"
            },
            status: {
                info: "#50a0ff",
                success: "#50d080",
                warning: "#e0c050",
                danger: "#f05060"
            },
            signal: {
                audio: "#50d080",
                microphone: "#f05060",
                brightness: "#e0c050"
            }
        },
        component: {
            bar: {
                background: "#101010",
                border: "#303030",
                clusterHover: "#202020",
                clusterActive: "#252545",
                clusterText: "#d0d0d0",
                clusterActiveText: "#f0f0f0"
            },
            panel: {
                background: "#101010",
                border: "#404040",
                section: "#202020",
                rowHover: "#252525",
                rowSelected: "#252545",
                rowDanger: "#402028"
            },
            control: {
                background: "#202020",
                hover: "#303030",
                pressed: "#404040",
                active: "#6060ff",
                disabled: "#181818",
                outline: "#404040",
                focus: "#5050ff",
                text: "#f0f0f0",
                textDisabled: "#707070",
                onActive: "#080808"
            },
            notification: {
                background: "#101010",
                border: "#404040"
            },
            osd: {
                border: "#404040",
                track: "#404040",
                fill: "#6060ff",
                text: "#f0f0f0"
            }
        },
        typography: {
            bodyFamily: "sans-serif",
            monoFamily: "monospace",
            iconFamily: "Material Symbols Rounded",
            baseSize: 13,
            captionSize: 11,
            headingSize: 17,
            weightRegular: 400,
            weightMedium: 500,
            weightBold: 700
        },
        metrics: {
            spaceUnit: 4,
            radiusSmall: 5,
            radiusMedium: 7,
            radiusLarge: 11,
            barHeight: 26,
            iconSmall: 15,
            iconMedium: 18,
            iconLarge: 24,
            panelWidth: 380,
            panelPadding: 16,
            rowHeight: 38
        },
        motion: {
            fast: 66,
            normal: 99,
            slow: 143
        },
        effects: {
            surfaceOpacity: 0.8
        }
    })

    Ui.ShellSlider {
        id: initialSlider

        visible: false
        theme: fixture.theme
        from: 0
        to: 100
        value: 150
    }

    Component {
        id: buttonComponent

        Ui.ShellButton {
            theme: fixture.theme
            label: "Apply"
        }
    }

    Component {
        id: toggleComponent

        Ui.ShellToggle {
            theme: fixture.theme
            label: "Wi-Fi"
        }
    }

    Component {
        id: sliderComponent

        Ui.ShellSlider {
            theme: fixture.theme
            label: "Volume"
            from: 0
            to: 100
            stepSize: 5
            value: 50
        }
    }

    Component {
        id: boundSliderComponent

        Ui.ShellSlider {
            theme: fixture.theme
            label: "Owner volume"
            from: 0
            to: 100
            stepSize: 5
            value: fixture.sliderOwnerValue
        }
    }

    Component {
        id: clusterComponent

        Ui.ShellBarCluster {
            theme: fixture.theme
            iconName: "network"
        }
    }

    Component {
        id: rowComponent

        Ui.ShellRow {
            theme: fixture.theme
            label: "Arrakis"
            selected: true
        }
    }

    Component {
        id: surfaceComponent

        Ui.ShellSurface {
            theme: fixture.theme
            selected: true
        }
    }

    Component {
        id: statusComponent

        Ui.ShellStatus {
            theme: fixture.theme
            status: "danger"
            label: "Failed"
        }
    }

    Component {
        id: stateComponent

        Ui.ShellStateView {
            theme: fixture.theme
            mode: "error"
            actionLabel: "Retry"
        }
    }

    Component {
        id: textComponent

        Ui.ShellText {
            theme: fixture.theme
            role: "danger"
            text: "Failure"
        }
    }

    Component {
        id: sectionComponent

        Ui.ShellSectionLabel {
            theme: fixture.theme
            text: "Available networks"
        }
    }

    Component {
        id: iconComponent

        Ui.ShellIcon {
            theme: fixture.theme
            name: "not-in-the-contract"
        }
    }

    Component {
        id: busyComponent

        Ui.ShellBusyIndicator {
            theme: fixture.theme
            reducedMotion: true
        }
    }

    IpcHandler {
        target: "stillsuit-ui-contract"

        function run(): string {
            return fixture.runContracts()
        }
    }

    function runContracts() {
        checks = 0
        var objects = []
        try {
            _assert(initialSlider.value === 100,
                "declarative slider value was not clamped at construction")

            var button = _create(buttonComponent, objects)
            var buttonClicks = 0
            button.clicked.connect(function() { buttonClicks++ })
            _assert(button.effectiveAccessibleName === "Apply",
                "labeled button lost its accessible name")
            _assert(button.activeFocusOnTab,
                "enabled button is missing tab focus")
            _assert(button.handleKey(Qt.Key_Space, 0, false),
                "Space did not activate the button")
            _assert(buttonClicks === 1, "button dispatched more than once")
            button.busy = true
            _assert(!button.trigger() && buttonClicks === 1,
                "busy button dispatched")
            button.busy = false
            button.enabled = false
            _assert(!button.handleKey(Qt.Key_Return, 0, false) && buttonClicks === 1,
                "disabled button dispatched")
            button.enabled = true
            button.reducedMotion = true
            _assert(button.motionDuration === 0,
                "button retained motion under reduced motion")
            button.label = ""
            button.iconName = "copy"
            _assert(button.effectiveAccessibleName === "copy",
                "icon-only button lacks an accessible name")

            var toggle = _create(toggleComponent, objects)
            var requestedToggle = null
            toggle.toggled.connect(function(next) { requestedToggle = next })
            _assert(toggle.trigger(), "toggle did not activate")
            _assert(toggle.checked === false && requestedToggle === true,
                "toggle mutated owner state before acceptance")
            toggle.checked = true
            toggle.trigger()
            _assert(toggle.checked === true && requestedToggle === false,
                "toggle did not propose the inverse owner state")
            toggle.busy = true
            requestedToggle = null
            _assert(!toggle.trigger() && requestedToggle === null,
                "busy toggle dispatched")

            var slider = _create(sliderComponent, objects)
            slider.value = 150
            _assert(slider.value === 100, "slider did not clamp an external value")
            slider.value = -20
            _assert(slider.value === 0, "slider did not clamp an external value")
            var movedValue = -1
            slider.moved.connect(function(next) { movedValue = next })
            _assert(slider.handleKey(Qt.Key_Right, 0, false),
                "Right did not adjust the slider")
            _assert(slider.value === 0 && movedValue === 5,
                "slider mutated owner state or proposed the wrong keyboard step")
            _assert(slider.handleKey(Qt.Key_End, 0, false) && slider.value === 0
                    && movedValue === 100,
                "End did not propose the maximum without mutating owner state")
            slider.busy = true
            _assert(!slider.moveTo(50) && slider.value === 0,
                "busy slider moved")
            slider.busy = false
            slider.enabled = false
            _assert(!slider.adjustBySteps(-1) && slider.value === 0,
                "disabled slider moved")

            var boundSlider = _create(boundSliderComponent, objects)
            var ownerRequest = -1
            boundSlider.moved.connect(function(next) {
                ownerRequest = next
                fixture.sliderOwnerValue = next
            })
            _assert(boundSlider.moveTo(55) && ownerRequest === 55
                    && boundSlider.value === 55,
                "owner-controlled slider did not accept published state")
            fixture.sliderOwnerValue = 70
            _assert(boundSlider.value === 70,
                "slider interaction severed its binding to owner state")

            var cluster = _create(clusterComponent, objects)
            _assert(cluster.effectiveAccessibleName === "network",
                "icon-only bar cluster lacks an accessible name")
            var clusterClicks = 0
            cluster.clicked.connect(function() { clusterClicks++ })
            _assert(cluster.handleKey(Qt.Key_Enter, 0, false) && clusterClicks === 1,
                "bar cluster keyboard activation failed")

            var row = _create(rowComponent, objects)
            _assert(row.visualBorderWidth === 0,
                "selected row gained a decorative border")
            row.danger = true
            _assert(row.visualBorderWidth === 0,
                "danger row gained a decorative border")
            var rowClicks = 0
            row.clicked.connect(function() { rowClicks++ })
            row.busy = true
            _assert(!row.trigger() && rowClicks === 0,
                "busy row dispatched")

            var surface = _create(surfaceComponent, objects)
            _assert(surface.border.width === 0,
                "selected surface gained a decorative border")
            surface.selected = false
            surface.danger = true
            _assert(surface.border.width === 0,
                "danger surface gained a decorative border")

            var status = _create(statusComponent, objects)
            _assert(status.effectiveAccessibleName === "Failed",
                "status lost its accessible name")
            _assert(String(status.color).toLowerCase() === "#402028",
                "danger status bypassed the panel assignment")

            var stateView = _create(stateComponent, objects)
            _assert(stateView.effectiveAccessibleName === "Something went wrong",
                "error state lacks a fallback accessible name")
            _assert(stateView.implicitHeight >= 112,
                "state view lost centered-state geometry")
            stateView.mode = "loading"
            _assert(stateView.effectiveAccessibleName === "Loading",
                "loading state lacks a fallback accessible name")
            stateView.mode = "empty"
            _assert(stateView.effectiveAccessibleName === "Nothing here",
                "empty state lacks a fallback accessible name")

            var text = _create(textComponent, objects)
            _assert(String(text.color).toLowerCase() === "#f05060",
                "status text bypassed the semantic role")

            var section = _create(sectionComponent, objects)
            _assert(section.monospace && section.sizeRole === "section",
                "section label lost approved typography")

            var icon = _create(iconComponent, objects)
            _assert(icon.text === icon._glyph("circle"),
                "unknown icon did not use the stable fallback glyph")

            var busy = _create(busyComponent, objects)
            _assert(busy.motionDuration === 0,
                "busy indicator retained motion under reduced motion")

            return JSON.stringify({ ok: true, checks: checks })
        } catch (error) {
            return JSON.stringify({ ok: false, checks: checks, error: String(error) })
        } finally {
            for (var index = objects.length - 1; index >= 0; index--)
                objects[index].destroy()
        }
    }

    function _create(component, objects) {
        var object = component.createObject(null)
        _assert(object !== null, "component did not construct")
        objects.push(object)
        return object
    }

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
        checks++
    }
}
