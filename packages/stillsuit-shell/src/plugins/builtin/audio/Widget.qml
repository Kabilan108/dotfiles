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
    active: context.panels && context.panels.isOpen("stillsuit.audio")
    onClicked: context.actions.surfaceToggle("stillsuit.audio", "")
}
