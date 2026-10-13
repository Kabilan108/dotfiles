import QtQuick
import "../../../ui" as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property var service
    required property string outputId

    theme: context.theme
    iconName: !service || !service.available || service.muted
        ? "volume-mute"
        : service.volume < 0.5
            ? "volume-down"
            : "volume-up"
    label: service && service.available && !service.muted
        ? Math.round(Math.min(1, service.volume) * 100) + "%"
        : ""
    accessibleName: !service || !service.available
        ? "Audio unavailable"
        : service.muted
            ? "Audio muted, open audio and media panel"
            : "Volume " + Math.round(Math.min(1, service.volume) * 100)
                + " percent, open audio and media panel"
    selected: context.panels && context.panels.selectedId === "stillsuit.audio"
        && context.panels.selectedOutputId === outputId
    onClicked: context.actions.surfaceToggle("stillsuit.audio", JSON.stringify({outputId: root.outputId}))

    MouseArea {
        objectName: "audio-volume-pointer"
        anchors.fill: parent
        enabled: root.canActivate && root.service && root.service.available
        acceptedButtons: Qt.MiddleButton
        onClicked: toggleMute()
        onWheel: function(wheel) { adjustVolume(wheel) }

        function toggleMute() {
            if (enabled)
                root.service.toggleMuted()
        }

        function adjustVolume(wheel) {
            if (!enabled) {
                wheel.accepted = false
                return
            }
            if (wheel.angleDelta.y === 0) {
                wheel.accepted = false
                return
            }
            root.service.setVolume(root.service.volume + wheel.angleDelta.y / 120 * 0.05)
            wheel.accepted = true
        }
    }
}
