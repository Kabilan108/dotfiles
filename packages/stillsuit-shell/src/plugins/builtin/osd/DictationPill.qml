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

    implicitWidth: content.implicitWidth + 36
    implicitHeight: barMaxHeight + 22

    function clamp(value, minimum, maximum) { return Math.min(Math.max(value, minimum), maximum) }
    function levelAt(index) {
        var values = dictator.levels || []
        return index < values.length && typeof values[index] === "number" ? values[index] : 0
    }
    function rounded(ctx, x, y, width, barHeight) {
        var radius = Math.min(barWidth / 2, width / 2, barHeight / 2)
        ctx.beginPath(); ctx.moveTo(x + radius, y); ctx.lineTo(x + width - radius, y)
        ctx.quadraticCurveTo(x + width, y, x + width, y + radius)
        ctx.lineTo(x + width, y + barHeight - radius); ctx.quadraticCurveTo(x + width, y + barHeight, x + width - radius, y + barHeight)
        ctx.lineTo(x + radius, y + barHeight); ctx.quadraticCurveTo(x, y + barHeight, x, y + barHeight - radius)
        ctx.lineTo(x, y + radius); ctx.quadraticCurveTo(x, y, x + radius, y); ctx.closePath()
    }
    function drawBar(ctx, index, barHeight, alpha) {
        ctx.globalAlpha = alpha
        rounded(ctx, index * (barWidth + barGap), (barMaxHeight - barHeight) / 2, barWidth, barHeight)
        ctx.fill()
    }
    function repaint() { waveform.requestPaint() }
    onDictatorChanged: repaint()

    Connections {
        target: root.dictator
        function onLevelsChanged() { root.repaint() }
        function onVisualizerStateChanged() { root.repaint() }
        function onScanPosChanged() { root.repaint() }
    }
    Ui.ShellSurface {
        anchors.fill: parent
        theme: root.context.theme
        kind: "osd"

        RowLayout {
            id: content

            anchors.centerIn: parent
            spacing: root.context.theme.metrics.spaceUnit * 3

            Canvas {
                id: waveform

                Layout.preferredWidth: root.waveformWidth
                Layout.preferredHeight: root.barMaxHeight
                antialiasing: true
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = root.activeColor
                    for (var index = 0; index < root.barCount; index++) {
                        var level = Math.pow(root.clamp((root.levelAt(index) - 0.2) / 0.8, 0, 1), 1.35)
                        var barHeight = root.barMinHeight + level * (root.barMaxHeight - root.barMinHeight)
                        if (root.dictator.visualizerState === "error") barHeight = root.barMinHeight
                        if (root.dictator.visualizerState === "transcribing" && !root.reducedMotion) {
                            var pulse = root.clamp(1 - Math.abs(index - root.dictator.scanPos) / 4, 0, 1)
                            barHeight = Math.max(barHeight * 0.34, root.barMinHeight + Math.pow(pulse, 0.8) * (root.barMaxHeight - root.barMinHeight))
                        }
                        root.drawBar(ctx, index, barHeight, root.dictator.visualizerState === "typing" ? 0.45 : 0.9)
                    }
                    ctx.globalAlpha = 1
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
