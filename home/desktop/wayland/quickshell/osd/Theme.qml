pragma Singleton

import Quickshell

Singleton {
    // Catppuccin Mocha palette
    readonly property string crust:     "#11111b"
    readonly property string mantle:    "#181825"
    readonly property string base_:     "#1e1e2e"
    readonly property string surface0:  "#313244"
    readonly property string surface1:  "#45475a"
    readonly property string surface2:  "#585b70"
    readonly property string overlay0:  "#6c7086"
    readonly property string overlay1:  "#7f849c"
    readonly property string overlay2:  "#9399b2"
    readonly property string subtext0:  "#a6adc8"
    readonly property string subtext1:  "#bac2de"
    readonly property string text:      "#cdd6f4"
    readonly property string rosewater: "#f5e0dc"
    readonly property string flamingo:  "#f2cdcd"
    readonly property string pink:      "#f5c2e7"
    readonly property string mauve:     "#cba6f7"
    readonly property string red:       "#f38ba8"
    readonly property string maroon:    "#eba0ac"
    readonly property string peach:     "#fab387"
    readonly property string yellow:    "#f9e2af"
    readonly property string green:     "#a6e3a1"
    readonly property string teal:      "#94e2d5"
    readonly property string sky:       "#89dceb"
    readonly property string sapphire:  "#74c7ec"
    readonly property string blue:      "#89b4fa"
    readonly property string lavender:  "#b4befe"

    // Semantic aliases
    readonly property string panelBg:     "#e0181825"
    readonly property string panelBorder: surface0
    readonly property string dimText:     subtext0
    readonly property string accent:      blue

    // Typography
    readonly property string fontFamily: "FiraMono Nerd Font"
    readonly property int fontSizeSmall:  11
    readonly property int fontSizeMedium: 13
    readonly property int fontSizeLarge:  16
    readonly property int fontSizeIcon:   20

    // Spacing & geometry
    readonly property int radiusSmall:  6
    readonly property int radiusMedium: 12
    readonly property int radiusLarge:  22
    readonly property int radiusPill:   9999

    readonly property int paddingSmall:  8
    readonly property int paddingMedium: 14
    readonly property int paddingLarge:  20

    readonly property int borderWidth: 1
}
