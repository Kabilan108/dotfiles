package main

import (
	"regexp"

	"github.com/charmbracelet/lipgloss"
)

// Catppuccin Mocha.
const (
	colorBase     = "#1e1e2e"
	colorSurface0 = "#313244"
	colorSurface1 = "#45475a"
	colorSurface2 = "#585b70"
	colorOverlay0 = "#6c7086"
	colorOverlay1 = "#7f849c"
	colorOverlay2 = "#9399b2"
	colorSubtext  = "#a6adc8"
	colorText     = "#cdd6f4"
	colorLavender = "#b4befe"
	colorBlue     = "#89b4fa"
	colorSapphire = "#74c7ec"
	colorSky      = "#89dceb"
	colorTeal     = "#94e2d5"
	colorGreen    = "#a6e3a1"
	colorYellow   = "#f9e2af"
	colorPeach    = "#fab387"
	colorRed      = "#f38ba8"
	colorMauve    = "#cba6f7"
)

// Nerd Font Material Design glyphs.
const (
	iconTerminal = "\U000F018D"
	iconFile     = "\U000F0214"
	iconReadme   = "\U000F0219"
	iconFolder   = "\U000F024B"
	iconGit      = "\U000F02A2"
	iconLaptop   = "\U000F0322"
	iconSearch   = "\U000F0349"
	iconAttached = "\U000F0379"
	iconNode     = "\U000F0399"
	iconPi       = "\U000F043F"
	iconRefresh  = "\U000F0453"
	iconServer   = "\U000F048B"
	iconStar     = "\U000F04CE"
	iconVim      = "\U000F0577"
	iconOffline  = "\U000F05AA"
	iconBranch   = "\U000F062C"
	iconAgent    = "\U000F06A9"
	iconCommit   = "\U000F0718"
	iconClock    = "\U000F0954"
)

// The fleet data has no icons, so machines are matched by name; any other
// host gets the server glyph the tmux status line uses.
var hostIcons = map[string]string{
	"jacurutu": iconLaptop,
	"sietch":   iconServer,
	"tleilax":  iconPi,
}

func hostIcon(host string) string {
	if icon, ok := hostIcons[host]; ok {
		return icon
	}
	return iconServer
}

var hexColor = regexp.MustCompile(`^#[0-9A-Fa-f]{6}$`)

func fg(color string) lipgloss.Style {
	style := lipgloss.NewStyle()
	if hexColor.MatchString(color) {
		style = style.Foreground(lipgloss.Color(color))
	}
	return style
}

func paint(color, text string) string {
	return fg(color).Render(text)
}

func bold(text string) string {
	return lipgloss.NewStyle().Bold(true).Render(text)
}
