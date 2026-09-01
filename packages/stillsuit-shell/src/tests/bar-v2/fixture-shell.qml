import QtQuick
import Quickshell
import Quickshell.Io
import "plugins/builtin/bar" as Bar
import "plugins/builtin/clock" as Clock
import "plugins/builtin/osd" as Osd
import "plugins/builtin/workspaces" as Workspaces

ShellRoot {
    id: fixture

    property int clockServiceInstances: 0
    property int workspaceConstructionCount: 0
    property var productionWorkspaceCounts: ({})
    readonly property string primaryOutputId: Quickshell.screens.length > 0
        ? String(Quickshell.screens[0].name)
        : ""
    readonly property string secondaryOutputId: Quickshell.screens.length > 1
        ? String(Quickshell.screens[1].name)
        : ""

    function recordWorkspace(outputId, count) {
        var next = Object.assign({}, productionWorkspaceCounts)
        next[String(outputId)] = count
        productionWorkspaceCounts = next
        workspaceConstructionCount++
    }

    QtObject {
        id: dictator

        property bool visible: false
        property string visualizerState: "listening"
        property string durationText: "00:03"
        property var levels: [0.2, 0.5, 0.8]
        property real scanPos: 1
    }

    QtObject {
        id: workflows

        property QtObject dictator: dictator
    }

    QtObject {
        id: serviceFacade

        function get(pluginId) {
            return pluginId === "stillsuit.workflows" ? workflows : null
        }
    }

    QtObject {
        id: osdService

        property real volume: 0.42
        property bool muted: false
        property bool volumeVisible: false
        property real brightness: 0.68
        property bool brightnessVisible: false
    }

    QtObject {
        id: settings

        property var values: ({ shadowMode: true, reducedMotion: false })
    }

    QtObject {
        id: context

        property var settings: settings
        property var services: serviceFacade
        property var actions: ({})
        property var logger: ({
            debug: function(message) {},
            info: function(message) {},
            warn: function(message) { console.warn(message) },
            error: function(message) { console.error(message) }
        })
        property var compositor: ({
            focusedOutputId: fixture.secondaryOutputId,
            workspaces: [
                { id: 1, idx: 1, output: fixture.primaryOutputId, is_active: true, active_window_id: 11 },
                { id: 2, idx: 1, output: fixture.secondaryOutputId, is_active: true, active_window_id: 22 },
                { id: 3, idx: 2, output: fixture.secondaryOutputId, is_urgent: true }
            ],
            windows: [
                { id: 11, workspace_id: 1, is_focused: true, layout: { pos_in_scrolling_layout: [1] } },
                { id: 22, workspace_id: 2, is_focused: true, layout: { pos_in_scrolling_layout: [2] } },
                { id: 23, workspace_id: 2, layout: { pos_in_scrolling_layout: [4] } }
            ]
        })
        property var theme: ({
            schemaVersion: 2,
            semantic: {
                surface: {
                    bar: "#181825", panel: "#181825", raised: "#313244",
                    overlay: "#1e1e2e", hover: "#45475a", pressed: "#585b70",
                    selected: "#2b3a57"
                },
                content: {
                    primary: "#cdd6f4", secondary: "#bac2de", muted: "#7f849c",
                    disabled: "#6c7086", inverse: "#11111b"
                },
                outline: {
                    subtle: "#313244", default: "#45475a", strong: "#6c7086",
                    focus: "#89b4fa"
                },
                accent: {
                    primary: "#89b4fa", hover: "#a9c9fb", pressed: "#6d9ee8",
                    subtle: "#2b3a57", onAccent: "#11111b"
                },
                status: {
                    info: "#89dceb", success: "#a6e3a1", warning: "#f9e2af",
                    danger: "#f38ba8"
                },
                signal: {
                    audio: "#a6e3a1", microphone: "#f38ba8",
                    brightness: "#f9e2af", charging: "#fab387",
                    recording: "#f38ba8"
                }
            },
            component: {
                bar: {
                    background: "#181825", border: "#313244", separator: "#45475a",
                    workspaceIdle: "#6c7086", workspaceActive: "#89b4fa",
                    clusterHover: "#45475a", clusterActive: "#2b3a57",
                    clusterText: "#bac2de", clusterActiveText: "#cdd6f4"
                },
                panel: {
                    background: "#181825", border: "#45475a", section: "#313244",
                    rowHover: "#45475a", rowSelected: "#2b3a57",
                    rowDanger: "#3b222b", shadow: "#11111b"
                },
                control: {
                    background: "#313244", hover: "#45475a", pressed: "#585b70",
                    active: "#89b4fa", disabled: "#181825", outline: "#45475a",
                    focus: "#89b4fa", text: "#cdd6f4", textDisabled: "#6c7086",
                    onActive: "#11111b"
                },
                notification: {
                    background: "#181825", border: "#45475a", unread: "#89b4fa",
                    info: "#89b4fa", success: "#a6e3a1", warning: "#f9e2af",
                    danger: "#f38ba8", muted: "#6c7086"
                },
                osd: {
                    border: "#45475a", track: "#45475a", fill: "#89b4fa",
                    text: "#cdd6f4"
                }
            },
            typography: {
                bodyFamily: "sans-serif", monoFamily: "monospace",
                iconFamily: "Material Symbols Rounded", baseSize: 13,
                captionSize: 11, headingSize: 17, weightRegular: 400,
                weightMedium: 500, weightBold: 700
            },
            metrics: {
                spaceUnit: 4, radiusSmall: 5, radiusMedium: 7, radiusLarge: 11,
                barHeight: 28, barOuterGap: 0, barInnerGap: 7,
                iconSmall: 15, iconMedium: 18, iconLarge: 24,
                panelWidth: 380, panelPadding: 16, rowHeight: 38
            },
            motion: {
                fast: 66, normal: 99, slow: 143,
                distanceSmall: 4, distanceMedium: 10, easing: "out-cubic"
            },
            effects: {
                surfaceOpacity: 0.8, blurEnabled: true, blurRadius: 24,
                shadowOpacity: 0.5
            }
        })
    }

    Clock.ClockService {
        id: clockService

        context: context
        Component.onCompleted: fixture.clockServiceInstances++
        Component.onDestruction: fixture.clockServiceInstances--
    }

    Component {
        id: workspaceComponent

        Workspaces.WorkspaceWidget {
            Component.onCompleted: fixture.recordWorkspace(outputId, workspaces.length)
        }
    }

    Component {
        id: clockComponent

        Clock.ClockWidget {}
    }

    Bar.Bar {
        id: productionBar

        context: context
        outputScreens: Quickshell.screens
        widgetRegistrations: [{
            component: workspaceComponent,
            context: context,
            manifest: { id: "stillsuit.workspaces" },
            defaultSection: "left",
            allowMultiple: false
        }, {
            component: clockComponent,
            context: context,
            service: clockService,
            manifest: { id: "stillsuit.clock" },
            defaultSection: "center",
            allowMultiple: false
        }]
    }

    Item {
        Workspaces.WorkspaceWidget {
            id: primaryWorkspaces
            context: context
            outputId: fixture.primaryOutputId
        }
        Workspaces.WorkspaceWidget {
            id: secondaryWorkspaces
            context: context
            outputId: fixture.secondaryOutputId
        }
        Clock.ClockWidget {
            id: clockView
            context: context
            service: clockService
            outputId: fixture.primaryOutputId
        }
        Osd.OsdBar {
            id: audioBar
            context: context
            iconName: "volume-up"
            signalRole: "audio"
            value: osdService.volume
            label: "42%"
        }
        Osd.OsdBar {
            id: brightnessBar
            context: context
            iconName: "brightness"
            signalRole: "brightness"
            value: osdService.brightness
            label: "68%"
        }
        Osd.DictationPill {
            id: dictationPill
            context: context
            dictator: dictator
        }
    }

    Osd.OsdOverlay {
        id: primaryOsd
        context: context
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        service: osdService
        outputId: fixture.primaryOutputId
    }

    Osd.OsdOverlay {
        id: secondaryOsd
        context: context
        screen: Quickshell.screens.length > 1 ? Quickshell.screens[1] : null
        service: osdService
        outputId: fixture.secondaryOutputId
    }

    IpcHandler {
        target: "stillsuit-bar-v2-fixture"

        function ready(): string {
            return fixture.clockServiceInstances === 1
                && fixture.workspaceConstructionCount === 2
                ? "ready"
                : "loading"
        }

        function contracts(): string {
            var microphoneSignal = String(dictationPill.activeColor)
                === String(context.theme.semantic.signal.microphone)
            dictator.visualizerState = "error"
            var dictationErrorSignal = String(dictationPill.activeColor)
                === String(context.theme.semantic.status.danger)
            dictator.visualizerState = "listening"
            return JSON.stringify({
                barHeight: productionBar.barHeight,
                outerGap: productionBar.outerGap,
                exclusionZone: productionBar.exclusionZone,
                constructionCount: fixture.workspaceConstructionCount,
                outputIds: [fixture.primaryOutputId, fixture.secondaryOutputId],
                primaryProductionWorkspaces: fixture.productionWorkspaceCounts[fixture.primaryOutputId],
                secondaryProductionWorkspaces: fixture.productionWorkspaceCounts[fixture.secondaryOutputId],
                primaryWorkspaces: primaryWorkspaces.workspaces.length,
                secondaryWorkspaces: secondaryWorkspaces.workspaces.length,
                secondaryColumns: secondaryWorkspaces.columns,
                secondaryFocusedColumn: secondaryWorkspaces.focusedColumn,
                inline: primaryWorkspaces.inlineLayout && secondaryWorkspaces.inlineLayout,
                clockServiceInstances: fixture.clockServiceInstances,
                osdViews: 2,
                osdOutputIds: [primaryOsd.outputId, secondaryOsd.outputId],
                sharedOsdService: primaryOsd.service === secondaryOsd.service,
                compactOsdBar: audioBar.implicitWidth === 268
                    && audioBar.implicitHeight === 44
                    && brightnessBar.implicitWidth === 268
                    && brightnessBar.implicitHeight === 44,
                osdPanelBackground: String(audioBar.backgroundColor) === String(context.theme.semantic.surface.panel),
                osdMediumRadius: audioBar.surfaceRadius === context.theme.metrics.radiusMedium,
                osdBorder: String(audioBar.borderColor) === String(context.theme.component.osd.border),
                osdTrack: String(audioBar.trackColor) === String(context.theme.component.osd.track),
                osdFillAssignment: String(audioBar.configuredFillColor) === String(context.theme.component.osd.fill),
                osdText: String(audioBar.textColor) === String(context.theme.component.osd.text),
                audioSignal: String(audioBar.signalColor) === String(context.theme.semantic.signal.audio),
                brightnessSignal: String(brightnessBar.signalColor) === String(context.theme.semantic.signal.brightness),
                microphoneSignal: microphoneSignal,
                dictationErrorSignal: dictationErrorSignal,
                dictationSurface: String(dictationPill.backgroundColor) === String(context.theme.semantic.surface.panel)
                    && String(dictationPill.borderColor) === String(context.theme.component.osd.border)
                    && String(dictationPill.textColor) === String(context.theme.component.osd.text)
                    && dictationPill.surfaceRadius === context.theme.metrics.radiusMedium,
                accessible: audioBar.accessibleName !== ""
                    && brightnessBar.accessibleName !== ""
                    && dictationPill.accessibleName !== ""
                    && primaryWorkspaces.accessibleName !== ""
                    && clockView.accessibleName !== ""
            })
        }

        function reducedMotion(): string {
            settings.values = ({ shadowMode: true, reducedMotion: true })
            return JSON.stringify({
                workspaceDuration: primaryWorkspaces.motionDuration,
                osdDuration: audioBar.motionDuration,
                dictationReduced: dictationPill.reducedMotion
            })
        }
    }
}
