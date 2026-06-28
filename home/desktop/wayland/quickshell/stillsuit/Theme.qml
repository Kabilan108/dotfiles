pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var data: fallbackData
    readonly property var fallbackData: ({
        palette: {
            crust: "#11111b",
            mantle: "#181825",
            base: "#1e1e2e",
            surface0: "#313244",
            surface1: "#45475a",
            surface2: "#585b70",
            overlay0: "#6c7086",
            overlay1: "#7f849c",
            overlay2: "#9399b2",
            subtext0: "#a6adc8",
            subtext1: "#bac2de",
            text: "#cdd6f4",
            rosewater: "#f5e0dc",
            flamingo: "#f2cdcd",
            pink: "#f5c2e7",
            mauve: "#cba6f7",
            red: "#f38ba8",
            maroon: "#eba0ac",
            peach: "#fab387",
            yellow: "#f9e2af",
            green: "#a6e3a1",
            teal: "#94e2d5",
            sky: "#89dceb",
            sapphire: "#74c7ec",
            blue: "#89b4fa",
            lavender: "#b4befe"
        },
        semantic: {
            panelBg: "#d911111b",
            panelBgSoft: "#d911111b",
            panelBgStrong: "#eb11111b",
            panelBorder: "#1acdd6f4",
            panelBorderStrong: "#45475a",
            panelSurface: "#b8313244",
            panelSurfaceHover: "#cc45475a",
            panelSurfaceActive: "#d9585b70",
            foreground: "#cdd6f4",
            dimText: "#a6adc8",
            mutedText: "#6c7086",
            accent: "#89b4fa",
            accent2: "#cdd6f4",
            bright: "#f9e2af",
            vol: "#a6e3a1",
            mic: "#f38ba8",
            charge: "#fab387",
            success: "#a6e3a1",
            warning: "#f9e2af",
            urgent: "#f38ba8",
            info: "#94e2d5",
            osdTrack: "#1fcdd6f4",
            osdFillMuted: "#45475a",
            shadow: "#6611111b"
        },
        typography: {
            fontFamily: "FiraMono Nerd Font",
            iconFamily: "Material Symbols Rounded",
            bodyFontFamily: "Noto Sans",
            fontSizeSmall: 11,
            fontSizeMedium: 13,
            fontSizeLarge: 16,
            fontSizeTitle: 14,
            fontSizeIcon: 20,
            fontSizeIconLarge: 24
        },
        geometry: {
            radiusSmall: 5,
            radiusMedium: 5,
            radiusLarge: 5,
            radiusPill: 9999,
            paddingSmall: 8,
            paddingMedium: 14,
            paddingLarge: 20,
            borderWidth: 1,
            panelWidth: 380,
            barHeight: 38,
            osdWidth: 360,
            osdHeight: 58,
            screenMargin: 8,
            panelGap: 8
        },
        animation: {
            fast: 120,
            medium: 180,
            slow: 260,
            osdHideMs: 1500,
            notificationDefaultMs: 5000,
            notificationLowMs: 4000
        }
    })

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/theme/stylix.json"
        watchChanges: true

        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(text())
            } catch (error) {
                console.warn("Failed to parse Stylix theme JSON:", error)
                root.data = root.fallbackData
            }
        }
        onLoadFailed: root.data = root.fallbackData
    }

    function value(section, key, fallback) {
        const group = root.data && root.data[section]
        if (!group || group[key] === undefined || group[key] === null) return fallback
        return group[key]
    }

    readonly property string crust:     value("palette", "crust", "#11111b")
    readonly property string mantle:    value("palette", "mantle", "#181825")
    readonly property string base_:     value("palette", "base", "#1e1e2e")
    readonly property string surface0:  value("palette", "surface0", "#313244")
    readonly property string surface1:  value("palette", "surface1", "#45475a")
    readonly property string surface2:  value("palette", "surface2", "#585b70")
    readonly property string overlay0:  value("palette", "overlay0", "#6c7086")
    readonly property string overlay1:  value("palette", "overlay1", "#7f849c")
    readonly property string overlay2:  value("palette", "overlay2", "#9399b2")
    readonly property string subtext0:  value("palette", "subtext0", "#a6adc8")
    readonly property string subtext1:  value("palette", "subtext1", "#bac2de")
    readonly property string text:      value("palette", "text", "#cdd6f4")
    readonly property string rosewater: value("palette", "rosewater", "#f5e0dc")
    readonly property string flamingo:  value("palette", "flamingo", "#f2cdcd")
    readonly property string pink:      value("palette", "pink", "#f5c2e7")
    readonly property string mauve:     value("palette", "mauve", "#cba6f7")
    readonly property string red:       value("palette", "red", "#f38ba8")
    readonly property string maroon:    value("palette", "maroon", "#eba0ac")
    readonly property string peach:     value("palette", "peach", "#fab387")
    readonly property string yellow:    value("palette", "yellow", "#f9e2af")
    readonly property string green:     value("palette", "green", "#a6e3a1")
    readonly property string teal:      value("palette", "teal", "#94e2d5")
    readonly property string sky:       value("palette", "sky", "#89dceb")
    readonly property string sapphire:  value("palette", "sapphire", "#74c7ec")
    readonly property string blue:      value("palette", "blue", "#89b4fa")
    readonly property string lavender:  value("palette", "lavender", "#b4befe")

    readonly property string panelBg:            value("semantic", "panelBg", "#e0181825")
    readonly property string panelBgSoft:        value("semantic", "panelBgSoft", panelBg)
    readonly property string panelBgStrong:      value("semantic", "panelBgStrong", panelBg)
    readonly property string panelBorder:        value("semantic", "panelBorder", surface0)
    readonly property string panelBorderStrong:  value("semantic", "panelBorderStrong", surface1)
    readonly property string panelSurface:       value("semantic", "panelSurface", surface0)
    readonly property string panelSurfaceHover:  value("semantic", "panelSurfaceHover", surface1)
    readonly property string panelSurfaceActive: value("semantic", "panelSurfaceActive", surface2)
    readonly property string foreground:         value("semantic", "foreground", text)
    readonly property string dimText:            value("semantic", "dimText", subtext0)
    readonly property string mutedText:          value("semantic", "mutedText", overlay0)
    readonly property string accent:             value("semantic", "accent", blue)
    readonly property string accent2:            value("semantic", "accent2", text)
    readonly property string bright:             value("semantic", "bright", yellow)
    readonly property string vol:                value("semantic", "vol", green)
    readonly property string mic:                value("semantic", "mic", red)
    readonly property string charge:             value("semantic", "charge", peach)
    readonly property string success:            value("semantic", "success", green)
    readonly property string warning:            value("semantic", "warning", yellow)
    readonly property string urgent:             value("semantic", "urgent", red)
    readonly property string info:               value("semantic", "info", teal)
    readonly property string osdTrack:           value("semantic", "osdTrack", "#1fcdd6f4")
    readonly property string osdFillMuted:       value("semantic", "osdFillMuted", surface1)
    readonly property string shadow:             value("semantic", "shadow", "#6611111b")

    readonly property string fontFamily: value("typography", "fontFamily", "FiraMono Nerd Font")
    readonly property string iconFamily: value("typography", "iconFamily", "Material Symbols Rounded")

    readonly property var icon: ({
        wifi: "\ue63e",
        wifi_off: "\ue648",
        network_wifi: "\ue1ba",
        network_wifi_3_bar: "\uebe1",
        network_wifi_2_bar: "\uebd6",
        network_wifi_1_bar: "\uebe4",
        signal_wifi_0_bar: "\uf0b0",
        signal_wifi_off: "\ue1da",
        bluetooth: "\ue1a7",
        bluetooth_connected: "\ue1a8",
        bluetooth_disabled: "\ue1a9",
        volume_up: "\ue050",
        volume_down: "\ue04d",
        volume_down_alt: "\ue79c",
        volume_mute: "\ue04e",
        volume_off: "\ue04f",
        mic: "\ue029",
        mic_off: "\ue02b",
        notifications: "\ue7f4",
        notifications_off: "\ue7f6",
        notifications_active: "\ue7f7",
        notifications_unread: "\uf4fe",
        battery_0_bar: "\uebdc",
        battery_1_bar: "\uebd9",
        battery_2_bar: "\uebe0",
        battery_3_bar: "\uebdd",
        battery_4_bar: "\uebe2",
        battery_5_bar: "\uebd4",
        battery_6_bar: "\uebd2",
        battery_charging_20: "\uf0a2",
        battery_charging_30: "\uf0a3",
        battery_charging_50: "\uf0a4",
        battery_charging_60: "\uf0a5",
        battery_charging_80: "\uf0a6",
        battery_charging_90: "\uf0a7",
        battery_full: "\ue1a4",
        battery_charging_full: "\ue1a3",
        battery_alert: "\ue19c",
        battery_unknown: "\ue1a6",
        screen_record: "\uf679",
        brightness_high: "\ue1ac",
        memory: "\ue322",
        memory_alt: "\uf7a3",
        speed: "\ue9e4",
        power_settings_new: "\ue8ac",
        refresh: "\ue5d5",
        lock: "\ue88d",
        check: "\ue5ca",
        close: "\ue14c",
        dark_mode: "\ue51c",
        delete: "\ue872",
        bluetooth_searching: "\ue1aa",
        sync: "\ue627",
        brightness_medium: "\ue1ae",
        brightness_low: "\ue1ad",
        warning: "\ue002",
        notification_important: "\ue004",
        music_note: "\ue3a1",
        graphic_eq: "\ue1b8",
        shuffle: "\ue043",
        shuffle_on: "\ue9e1",
        skip_previous: "\ue045",
        skip_next: "\ue044",
        play_arrow: "\ue037",
        pause: "\ue034",
        repeat: "\ue040",
        repeat_one: "\ue041",
        repeat_on: "\ue9d6",
        repeat_one_on: "\ue9d7"
    })

    readonly property string bodyFontFamily: value("typography", "bodyFontFamily", "Noto Sans")
    readonly property int fontSizeSmall:  value("typography", "fontSizeSmall", 11)
    readonly property int fontSizeMedium: value("typography", "fontSizeMedium", 13)
    readonly property int fontSizeLarge:  value("typography", "fontSizeLarge", 16)
    readonly property int fontSizeTitle:  value("typography", "fontSizeTitle", 14)
    readonly property int fontSizeIcon:   value("typography", "fontSizeIcon", 20)
    readonly property int fontSizeIconLarge: value("typography", "fontSizeIconLarge", 24)

    readonly property int radiusSmall:  value("geometry", "radiusSmall", 6)
    readonly property int radiusMedium: value("geometry", "radiusMedium", 12)
    readonly property int radiusLarge:  value("geometry", "radiusLarge", 22)
    readonly property int radiusPill:   value("geometry", "radiusPill", 9999)

    readonly property int paddingSmall:  value("geometry", "paddingSmall", 8)
    readonly property int paddingMedium: value("geometry", "paddingMedium", 14)
    readonly property int paddingLarge:  value("geometry", "paddingLarge", 20)

    readonly property int borderWidth: value("geometry", "borderWidth", 1)
    readonly property int panelWidth: value("geometry", "panelWidth", 380)
    readonly property int barHeight: value("geometry", "barHeight", 38)
    readonly property int osdWidth: value("geometry", "osdWidth", 320)
    readonly property int osdHeight: value("geometry", "osdHeight", 50)
    readonly property int screenMargin: value("geometry", "screenMargin", 12)
    readonly property int panelGap: value("geometry", "panelGap", 8)

    readonly property int animationFast: value("animation", "fast", 120)
    readonly property int animationMedium: value("animation", "medium", 180)
    readonly property int animationSlow: value("animation", "slow", 260)
    readonly property int osdHideMs: value("animation", "osdHideMs", 1500)
    readonly property int notificationDefaultMs: value("animation", "notificationDefaultMs", 5000)
    readonly property int notificationLowMs: value("animation", "notificationLowMs", 4000)
}
