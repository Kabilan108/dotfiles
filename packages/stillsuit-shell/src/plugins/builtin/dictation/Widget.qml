import QtQuick
import "../../../ui" as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property var service
    required property string outputId

    readonly property string state: service ? service.state : "idle"
    readonly property bool live: service && service.connected

    theme: context.theme
    iconName: "microphone"
    contentColor: state === "recording"
        ? context.theme.semantic.signal.microphone
        : state === "transcribing" || state === "typing"
            ? context.theme.semantic.status.info
            : state === "error"
                ? context.theme.semantic.status.danger
                : !live
                    ? context.theme.semantic.content.muted
                    : selected
                        ? context.theme.component.bar.clusterActiveText
                        : context.theme.component.bar.clusterText
    accessibleName: !live
        ? "Dictation unavailable, open dictation panel"
        : state === "recording"
            ? "Recording, open dictation panel"
            : state === "transcribing"
                ? "Transcribing, open dictation panel"
                : "Dictation ready, open dictation panel"
    selected: context.panels && context.panels.selectedId === "stillsuit.dictation"
        && context.panels.selectedOutputId === outputId
    onClicked: context.actions.surfaceToggle("stillsuit.dictation", JSON.stringify({ outputId: root.outputId }))
}
