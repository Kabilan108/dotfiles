import QtQuick
import QtQuick.Layouts
import "../../../ui" as Ui

Item {
    id: root

    required property var context
    required property QtObject dictator

    readonly property int barCount: 23
    readonly property real barWidth: 2.5
    readonly property real barGap: 3
    readonly property real barMinHeight: 3
    readonly property real barMaxHeight: 16
    readonly property real waveformWidth: barCount * barWidth + (barCount - 1) * barGap
    readonly property bool reducedMotion: context.settings
        && context.settings.values
        && context.settings.values.reducedMotion === true
    readonly property color backgroundColor: context.theme.semantic.surface.panel
    readonly property color borderColor: context.theme.component.osd.border
    readonly property color textColor: context.theme.component.osd.text
    readonly property real surfaceRadius: context.theme.metrics.radiusMedium
    readonly property color activeColor: dictator.visualizerState === "error"
        ? context.theme.semantic.status.danger
        : context.theme.semantic.signal.microphone
    readonly property string accessibleName: dictator.visualizerState === "error"
        ? "Dictation error"
        : "Dictation " + dictator.visualizerState

    implicitWidth: 216
    implicitHeight: barMaxHeight + 22

    function clamp(value, minimum, maximum) { return Math.min(Math.max(value, minimum), maximum) }
    function levelAt(index) {
        var values = dictator.levels || []
        return index < values.length && typeof values[index] === "number" ? values[index] : 0
    }
    function barHeightAt(index) {
        if (dictator.visualizerState === "error") return barMinHeight
        var level = Math.pow(clamp((levelAt(index) - 0.2) / 0.8, 0, 1), 1.35)
        var barHeight = barMinHeight + level * (barMaxHeight - barMinHeight)
        if (dictator.visualizerState === "transcribing" && !root.reducedMotion) {
            var pulse = clamp(1 - Math.abs(index - dictator.scanPos) / 4, 0, 1)
            barHeight = Math.max(barHeight * 0.34, barMinHeight + Math.pow(pulse, 0.8) * (barMaxHeight - barMinHeight))
        }
        return barHeight
    }
    Ui.ShellSurface {
        anchors.fill: parent
        theme: root.context.theme
        kind: "osd"

        RowLayout {
            id: content

            anchors.centerIn: parent
            spacing: root.context.theme.metrics.spaceUnit * 3

            // Scene-graph rectangles need no JS repaint or texture upload per
            // scan tick, unlike a Canvas.
            Item {
                id: waveform

                Layout.preferredWidth: root.waveformWidth
                Layout.preferredHeight: root.barMaxHeight
                opacity: root.dictator.visualizerState === "typing" ? 0.45 : 0.9

                Repeater {
                    model: root.barCount

                    Rectangle {
                        required property int index

                        x: index * (root.barWidth + root.barGap)
                        y: (root.barMaxHeight - height) / 2
                        width: root.barWidth
                        height: root.barHeightAt(index)
                        radius: Math.min(width, height) / 2
                        antialiasing: true
                        color: root.activeColor
                    }
                }
            }
            Rectangle {
                visible: root.dictator.durationText !== ""
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                color: root.context.theme.component.osd.track
            }
            Ui.ShellText {
                visible: root.dictator.durationText !== ""
                theme: root.context.theme
                text: root.dictator.durationText
                color: root.context.theme.component.osd.text
                monospace: true
            }
        }
    }
}
