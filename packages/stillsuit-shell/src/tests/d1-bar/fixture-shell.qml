import QtQuick
import Quickshell
import "bar"

ShellRoot {
    Bar {
        context: QtObject {
            readonly property var theme: ({
                colors: {
                    surface: { panel: "#1e1e2e" },
                    border: { normal: "#45475a", focus: "#89b4fa" },
                    text: { primary: "#cdd6f4", secondary: "#a6adc8" }
                },
                typography: { family: "sans-serif", baseSize: 13 },
                geometry: { barHeight: 34, panelGap: 6, radius: 8 }
            })
            readonly property QtObject compositor: QtObject {
                readonly property string focusedOutputId: ""
            }
            readonly property QtObject settings: QtObject {
                readonly property var values: ({ shadowMode: true })
            }
        }
        widgetRegistrations: []
        outputScreens: []
    }

    Timer {
        interval: 20
        running: true
        onTriggered: Qt.quit()
    }
}
