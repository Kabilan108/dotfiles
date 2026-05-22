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
            panelBg: "#e0181825",
            panelBorder: "#313244",
            dimText: "#a6adc8",
            accent: "#89b4fa",
            osdTrack: "#1fcdd6f4"
        },
        typography: {
            fontFamily: "FiraMono Nerd Font",
            fontSizeSmall: 11,
            fontSizeMedium: 13,
            fontSizeLarge: 16,
            fontSizeIcon: 20
        },
        geometry: {
            radiusSmall: 6,
            radiusMedium: 12,
            radiusLarge: 22,
            radiusPill: 9999,
            paddingSmall: 8,
            paddingMedium: 14,
            paddingLarge: 20,
            borderWidth: 1
        }
    })

    FileView {
        path: Quickshell.configPath("theme/stylix.json")
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

    readonly property string panelBg:     value("semantic", "panelBg", "#e0181825")
    readonly property string panelBorder: value("semantic", "panelBorder", surface0)
    readonly property string dimText:     value("semantic", "dimText", subtext0)
    readonly property string accent:      value("semantic", "accent", blue)
    readonly property string osdTrack:    value("semantic", "osdTrack", "#1fcdd6f4")

    readonly property string fontFamily: value("typography", "fontFamily", "FiraMono Nerd Font")
    readonly property int fontSizeSmall:  value("typography", "fontSizeSmall", 11)
    readonly property int fontSizeMedium: value("typography", "fontSizeMedium", 13)
    readonly property int fontSizeLarge:  value("typography", "fontSizeLarge", 16)
    readonly property int fontSizeIcon:   value("typography", "fontSizeIcon", 20)

    readonly property int radiusSmall:  value("geometry", "radiusSmall", 6)
    readonly property int radiusMedium: value("geometry", "radiusMedium", 12)
    readonly property int radiusLarge:  value("geometry", "radiusLarge", 22)
    readonly property int radiusPill:   value("geometry", "radiusPill", 9999)

    readonly property int paddingSmall:  value("geometry", "paddingSmall", 8)
    readonly property int paddingMedium: value("geometry", "paddingMedium", 14)
    readonly property int paddingLarge:  value("geometry", "paddingLarge", 20)

    readonly property int borderWidth: value("geometry", "borderWidth", 1)
}
