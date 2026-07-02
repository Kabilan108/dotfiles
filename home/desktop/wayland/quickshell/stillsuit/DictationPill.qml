import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string mode: "recording"
    property var levels: []
    property string durationText: ""

    readonly property bool showDuration: durationText.length > 0

    readonly property int barCount: 23
    readonly property real barWidth: 2.5
    readonly property real barGap: 3
    readonly property real barMinHeight: 3
    readonly property real barMaxHeight: 16
    readonly property real hPadding: 18
    readonly property real vPadding: 11
    readonly property real waveformWidth: (barCount * barWidth) + ((barCount - 1) * barGap)

    readonly property bool errored: root.mode === "error"
    readonly property color activeColor: errored ? Theme.urgent : Theme.accent

    property real scanPos: 0

    implicitWidth: content.implicitWidth + hPadding * 2
    implicitHeight: barMaxHeight + vPadding * 2
    radius: Theme.radiusPill
    color: Theme.panelChrome
    border.width: Theme.borderWidth
    border.color: Theme.panelBorder

    function clamp(value, min, max) {
        return Math.min(Math.max(value, min), max)
    }

    function displayLevel(level) {
        const floor = 0.2
        return Math.pow(clamp((level - floor) / (1 - floor), 0, 1), 1.35)
    }

    function levelAt(i) {
        const v = root.levels
        return (v && i < v.length && typeof v[i] === "number") ? v[i] : 0
    }

    function roundedRect(ctx, x, y, w, h, r) {
        const rad = Math.min(r, w / 2, h / 2)
        ctx.beginPath()
        ctx.moveTo(x + rad, y)
        ctx.lineTo(x + w - rad, y)
        ctx.quadraticCurveTo(x + w, y, x + w, y + rad)
        ctx.lineTo(x + w, y + h - rad)
        ctx.quadraticCurveTo(x + w, y + h, x + w - rad, y + h)
        ctx.lineTo(x + rad, y + h)
        ctx.quadraticCurveTo(x, y + h, x, y + h - rad)
        ctx.lineTo(x, y + rad)
        ctx.quadraticCurveTo(x, y, x + rad, y)
        ctx.closePath()
    }

    function drawBar(ctx, i, height, alpha) {
        const x = i * (root.barWidth + root.barGap)
        const y = (root.barMaxHeight - height) / 2
        ctx.globalAlpha = alpha
        root.roundedRect(ctx, x, y, root.barWidth, height, root.barWidth / 2)
        ctx.fill()
    }

    function drawWave(ctx, alphaScale) {
        for (let i = 0; i < root.barCount; i++) {
            const level = root.displayLevel(root.levelAt(i))
            const h = root.barMinHeight + (level * (root.barMaxHeight - root.barMinHeight))
            const alpha = Math.min(0.9, (0.4 + (level * 0.5)) * alphaScale)
            root.drawBar(ctx, i, h, alpha)
        }
    }

    function drawTranscribing(ctx) {
        drawWave(ctx, 0.34)
        for (let i = 0; i < root.barCount; i++) {
            const distance = Math.abs(i - root.scanPos)
            const level = root.clamp(1 - (distance / 4), 0, 1)
            if (level <= 0) continue
            const h = root.barMinHeight + (Math.pow(level, 0.8) * (root.barMaxHeight - root.barMinHeight))
            root.drawBar(ctx, i, h, 0.2 + (level * 0.75))
        }
    }

    function drawError(ctx) {
        for (let i = 0; i < root.barCount; i++) {
            root.drawBar(ctx, i, root.barMinHeight, 0.55)
        }
    }

    onModeChanged: waveform.requestPaint()
    onLevelsChanged: waveform.requestPaint()

    Timer {
        interval: 16
        repeat: true
        running: root.visible && root.mode === "transcribing"
        onTriggered: {
            root.scanPos = (root.scanPos + 0.2) % (root.barCount + 5)
            waveform.requestPaint()
        }
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 11

        Canvas {
            id: waveform
            Layout.preferredWidth: root.waveformWidth
            Layout.preferredHeight: root.barMaxHeight
            Layout.alignment: Qt.AlignVCenter
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = root.activeColor

                if (root.mode === "transcribing") root.drawTranscribing(ctx)
                else if (root.mode === "error") root.drawError(ctx)
                else if (root.mode === "typing") root.drawWave(ctx, 0.5)
                else root.drawWave(ctx, 1)

                ctx.globalAlpha = 1
            }
        }

        Rectangle {
            visible: root.showDuration
            Layout.preferredWidth: Theme.borderWidth
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter
            color: Theme.panelBorder
        }

        Text {
            visible: root.showDuration
            text: root.durationText
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMedium
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
