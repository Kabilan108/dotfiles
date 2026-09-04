.pragma library

function create() {
    return {
        schemaVersion: 2,
        identity: { id: "stillsuit.fixture", name: "Fixture", mode: "dark" },
        semantic: {
            background: {
                canvas: "#11111b", desktop: "#11111b", scrim: "#000000"
            },
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
            },
            resources: {
                normal: "#a6e3a1", elevated: "#f9e2af",
                high: "#fab387", critical: "#f38ba8"
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
            barHeight: 26, barOuterGap: 0, barInnerGap: 7,
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
    }
}
