import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Per-output presentation only. The workflow service, recorder state, and
// Dictator socket stay global in stillsuit.workflows.
Scope {
    id: root

    required property var context
    required property var screen
    required property QtObject service
    required property string outputId

    property var workflows: context.services.get("stillsuit.workflows")
    property var dictator: workflows ? workflows.dictator : null
    readonly property bool dictatorVisible: dictator && dictator.visible
    readonly property bool visible: service.volumeVisible || service.brightnessVisible || dictatorVisible
    PanelWindow {
        screen: root.screen
        visible: root.visible
        anchors.bottom: true
        margins.bottom: root.screen.height * 0.02
        exclusiveZone: 0
        aboveWindows: true
        focusable: false
        color: "transparent"
        implicitWidth: column.implicitWidth
        implicitHeight: column.implicitHeight
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "stillsuit-osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        ColumnLayout {
            id: column
            spacing: root.context.theme.metrics.spaceUnit * 2
            OsdBar {
                visible: root.service.volumeVisible
                context: root.context
                iconName: root.service.muted ? "volume-mute" : "volume-up"
                value: root.service.volume
                signalRole: "audio"
                label: root.service.muted ? "Mute" : Math.round(root.service.volume * 100) + "%"
                accessibleName: root.service.muted ? "Audio muted" : "Audio volume " + label
            }
            OsdBar {
                visible: root.service.brightnessVisible
                context: root.context
                iconName: "brightness"
                value: root.service.brightness
                signalRole: "brightness"
                label: Math.round(Math.max(0, root.service.brightness) * 100) + "%"
                accessibleName: "Display brightness " + label
            }
            DictationPill {
                visible: root.dictatorVisible
                context: root.context
                dictator: root.dictator
            }
        }
    }
}
